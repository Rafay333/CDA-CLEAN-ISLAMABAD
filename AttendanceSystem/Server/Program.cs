using System.Text; using FaceRecognitionDotNet; using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddCors();
var app = builder.Build();
app.UseCors(x => x.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()); // needed only when testing the app in Chrome; tighten later
var adminUser = app.Configuration["Admin:User"] ?? "admin";
var adminPass = app.Configuration["Admin:Password"] ?? "";
app.Use(async (ctx, next) => {
    var path = ctx.Request.Path.Value ?? "/";
    bool mobile = path.StartsWith("/api/login") || path.StartsWith("/api/enroll") || path.StartsWith("/api/checkin") || path.StartsWith("/api/scan");
    bool admin = !mobile && (path == "/" || path.StartsWith("/index") || path.StartsWith("/api/"));
    if (admin) {
        if (!Db.IsLan(ctx.Connection.RemoteIpAddress)) { ctx.Response.StatusCode = 403; await ctx.Response.WriteAsync("The admin page is only available inside the office network."); return; }
        bool ok = false;
        var h = ctx.Request.Headers.Authorization.ToString();
        if (adminPass.Length > 0 && h.StartsWith("Basic ")) {
            try { ok = Encoding.UTF8.GetString(Convert.FromBase64String(h.Substring(6))) == adminUser + ":" + adminPass; } catch { }
        }
        if (!ok) { ctx.Response.StatusCode = 401; ctx.Response.Headers["WWW-Authenticate"] = "Basic realm=\"Attendance Admin\""; return; }
    }
    await next();
});
app.UseDefaultFiles(); app.UseStaticFiles();
var fr = FaceRecognition.Create(Path.Combine(app.Environment.ContentRootPath, "models"));

Db.Cs = app.Configuration.GetConnectionString("Default")!;
FaceStore.Init(fr);
Live.Config = app.Configuration;
// Check-in photos are deleted automatically after 30 days.
Task.Run(async () => { while (true) { try { Db.Q("DELETE FROM CheckinPhotos WHERE Time < DATEADD(day,-30,SYSDATETIME())"); } catch { } await Task.Delay(TimeSpan.FromHours(6)); } });


// ---- Employees (admin page) ----
app.MapGet("/api/employees", () => Db.Q("SELECT Id,Code,Name,Department,Active,AllowOthers,Blocked,BlockReason,CASE WHEN FaceImage IS NULL THEN 0 ELSE 1 END AS Enrolled FROM Employees ORDER BY Name"));
app.MapGet("/api/employees/nextcode", () => Db.Q("SELECT CAST(ISNULL(MAX(TRY_CAST(Code AS INT)),999)+1 AS NVARCHAR(50)) AS Code FROM Employees")[0]["Code"]);
app.MapPost("/api/employees", (Emp e) => { try { Db.Q("INSERT INTO Employees(Code,Name,Department,Active) SELECT CAST(ISNULL(MAX(TRY_CAST(Code AS INT)),999)+1 AS NVARCHAR(50)),@n,@d,@a FROM Employees", ("@n", e.Name), ("@d", e.Department), ("@a", e.Active ? 1 : 0)); return Results.Ok(); } catch (Exception ex) { return Results.BadRequest("Could not add employee: " + ex.Message); } });
app.MapPut("/api/employees/{id}", (int id, Emp e) => { Db.Q("UPDATE Employees SET Name=@n,Department=@d,Active=@a WHERE Id=@i", ("@n", e.Name), ("@d", e.Department), ("@a", e.Active ? 1 : 0), ("@i", id)); return Results.Ok(); });
app.MapDelete("/api/employees/{id}", (int id) => { Db.Q("DELETE FROM EmployeeLocations WHERE EmployeeId=@i; DELETE FROM EmployeeFaces WHERE EmployeeId=@i; DELETE FROM Employees WHERE Id=@i", ("@i", id)); FaceStore.Remove(id); return Results.Ok(); });
app.MapPost("/api/employees/{id}/allowothers/{v}", (int id, int v) => { Db.Q("UPDATE Employees SET AllowOthers=@v WHERE Id=@i", ("@v", v), ("@i", id)); return Results.Ok(); });
app.MapPost("/api/employees/{id}/resetface", (int id) => { Db.Q("DELETE FROM EmployeeFaces WHERE EmployeeId=@i; UPDATE Employees SET FaceImage=NULL, RegisteredDeviceId=NULL WHERE Id=@i", ("@i", id)); FaceStore.Remove(id); return Results.Ok(); });

// ---- Locations ----
app.MapGet("/api/locations", () => Db.Q("SELECT l.Id,l.Name,l.Lat,l.Lng,l.RadiusM,(SELECT COUNT(*) FROM EmployeeLocations WHERE LocationId=l.Id) AS Assigned FROM Locations l ORDER BY l.Name"));
app.MapGet("/api/employees/{id}/locations", (int id) => Db.Q("SELECT LocationId FROM EmployeeLocations WHERE EmployeeId=@i", ("@i", id)).Select(r => Convert.ToInt32(r["LocationId"])));
app.MapPut("/api/employees/{id}/locations", (int id, int[] ids) => { Db.Q("DELETE FROM EmployeeLocations WHERE EmployeeId=@i", ("@i", id)); foreach (var x in ids) Db.Q("INSERT INTO EmployeeLocations VALUES(@i,@l)", ("@i", id), ("@l", x)); return Results.Ok(); });
app.MapPost("/api/locations", (Loc l) => { Db.Q("INSERT INTO Locations(Name,Lat,Lng,RadiusM) VALUES(@n,@a,@b,@r)", ("@n", l.Name), ("@a", l.Lat), ("@b", l.Lng), ("@r", Db.DefaultRadius)); return Results.Ok(); });
app.MapDelete("/api/locations/{id}", (int id) => { Db.Q("DELETE FROM EmployeeLocations WHERE LocationId=@i; DELETE FROM Locations WHERE Id=@i", ("@i", id)); return Results.Ok(); });

// ---- Attendance records (admin page) ----
app.MapGet("/api/attendance", (HttpRequest req) => {
    var f = DateTime.TryParse(req.Query["from"], out var d1) ? d1.Date : DateTime.Today;
    var t = DateTime.TryParse(req.Query["to"], out var d2) ? d2.Date : DateTime.Today;
    return Db.Q(@"SELECT a.Id, e.Code, e.Name, l.Name AS Location, a.Time, a.Similarity, a.Accuracy, a.CheckinPhotoId,
        ISNULL(CASE WHEN a.DeviceOwnerId=a.EmployeeId THEN 'Own phone' ELSE o.Name END,'Unknown') AS PhoneOf
        FROM Attendance a LEFT JOIN Employees e ON e.Id=a.EmployeeId LEFT JOIN Locations l ON l.Id=a.LocationId LEFT JOIN Employees o ON o.Id=a.DeviceOwnerId
        WHERE a.Time >= @f AND a.Time < DATEADD(day,1,@t) AND (@e='' OR e.Code=@e) ORDER BY a.Time DESC",
        ("@f", f), ("@t", t), ("@e", req.Query["emp"].ToString()));
});

app.MapPost("/api/employees/{id}/unblock", (int id) => { Db.Q("UPDATE Employees SET Blocked=0, BlockReason=NULL, BlockedAt=NULL WHERE Id=@i", ("@i", id)); return Results.Ok(); });
app.MapGet("/api/alerts", () => Db.Q("SELECT TOP 200 a.Id, a.EmployeeId, a.Time, a.Kind, a.Detail, a.Seen, e.Code, e.Name, ISNULL(e.Blocked,0) AS Blocked FROM Alerts a LEFT JOIN Employees e ON e.Id=a.EmployeeId ORDER BY a.Id DESC"));
app.MapGet("/api/alerts/summary", () => Db.Q("SELECT (SELECT COUNT(*) FROM Employees WHERE Blocked=1) AS Blocked, (SELECT COUNT(*) FROM Alerts WHERE Seen=0) AS Unseen")[0]);
app.MapPost("/api/alerts/seen", () => { Db.Q("UPDATE Alerts SET Seen=1 WHERE Seen=0"); return Results.Ok(); });

// ---- Mobile app ----
app.MapPost("/api/login", (LoginReq r) => {
    var e = Db.Q("SELECT Id,Name,Active,AllowOthers,RegisteredDeviceId,Blocked,CASE WHEN FaceImage IS NULL THEN 0 ELSE 1 END AS Enrolled FROM Employees WHERE Code=@c", ("@c", r.Code)).FirstOrDefault();
    if (e == null || Convert.ToInt64(e["Active"]) == 0) return Results.NotFound("Unknown or inactive ID");
    if (Convert.ToInt64(e["Blocked"]) == 1) return Results.BadRequest("Your ID is blocked. Contact the admin.");
    if (!r.AsOwner) { var blk = Db.DeviceBlock(r.DeviceId, e["Id"], Convert.ToInt64(e["Enrolled"]) == 1); if (blk != null) return Results.BadRequest(blk); }
    if (r.AsOwner && !string.IsNullOrEmpty(r.DeviceId))
        Db.Q("IF NOT EXISTS(SELECT 1 FROM Devices WHERE DeviceId=@d) INSERT INTO Devices VALUES(@d,@e,SYSDATETIME())", ("@d", r.DeviceId), ("@e", e["Id"]));
    if (r.AsOwner && Convert.ToInt64(e["Enrolled"]) == 1 && !string.IsNullOrEmpty(e["RegisteredDeviceId"] as string) && (string)e["RegisteredDeviceId"]! != r.DeviceId) return Results.BadRequest("Your face is registered on another phone. Ask the admin to reset it.");
    return Results.Ok(new { name = e["Name"], enrolled = Convert.ToInt64(e["Enrolled"]) == 1, allowOthers = Convert.ToInt64(e["AllowOthers"]) == 1 });
});
app.MapPost("/api/enroll", async (HttpRequest req) => {
    var f = await req.ReadFormAsync(); var code = f["code"].ToString(); var dev = f["deviceId"].ToString();
    var e = Db.Q("SELECT Id,FaceImage,Blocked FROM Employees WHERE Code=@c AND Active=1", ("@c", code)).FirstOrDefault();
    if (e == null) return Results.NotFound("Unknown ID");
    if (e["FaceImage"] != null) return Results.BadRequest("Already registered. Ask the admin to reset your face.");
    var own = Db.Q("SELECT OwnerEmployeeId FROM Devices WHERE DeviceId=@d", ("@d", dev)).FirstOrDefault();
    if (own == null && dev.Length > 0) Db.Q("INSERT INTO Devices VALUES(@d,@e,SYSDATETIME())", ("@d", dev), ("@e", e["Id"]));
    else if (own == null || Convert.ToInt32(own["OwnerEmployeeId"]) != Convert.ToInt32(e["Id"])) return Results.BadRequest("Face registration is only allowed on your own phone.");
    if (f.Files.Count < 3) return Results.BadRequest("Three photos are required.");
    if (!FaceStore.Ready) return Results.BadRequest("Face data is still loading. Try again in a minute.");
    int id = Convert.ToInt32(e["Id"]); var imgs = new List<byte[]>(); var encs = new List<FaceEncoding>();
    for (int i = 0; i < 3; i++) {
        var b = await Db.Bytes(f.Files[i]); var fe = FaceStore.EncodeSafe(b, out int n);
        if (n != 1) return Results.BadRequest($"Photo {i + 1}: exactly one clear face is needed. Try again in good light.");
        imgs.Add(b); encs.Add(fe!);
    }
    if (FaceStore.Dist(encs[0], encs[1]) > 0.45 || FaceStore.Dist(encs[0], encs[2]) > 0.45 || FaceStore.Dist(encs[1], encs[2]) > 0.45)
        return Results.BadRequest("The three photos do not look like the same person. Try again.");
    var (did, dbest, _) = FaceStore.Identify(encs, id);
    if (did >= 0 && dbest <= 0.50) { var o = Db.Q("SELECT Code FROM Employees WHERE Id=@i", ("@i", did)).FirstOrDefault(); return Results.BadRequest($"This face is already registered under employee {o?["Code"]}."); }
    Db.Q("DELETE FROM EmployeeFaces WHERE EmployeeId=@e", ("@e", id));
    foreach (var im in imgs) Db.Q("INSERT INTO EmployeeFaces(EmployeeId,Image,Created) VALUES(@e,@i,SYSDATETIME())", ("@e", id), ("@i", im));
    Db.Q("UPDATE Employees SET FaceImage=@f, RegisteredDeviceId=@d WHERE Id=@e", ("@f", imgs[0]), ("@d", dev), ("@e", id));
    FaceStore.Set(id, encs);
    return Results.Ok("Face registered");
});
app.MapPost("/api/checkin", async (HttpRequest req) => {
    var f = await req.ReadFormAsync(); var code = f["code"].ToString(); var dev = f["deviceId"].ToString();
    double lat = double.Parse(f["lat"]!), lng = double.Parse(f["lng"]!);
    double acc = double.TryParse(f["acc"], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var ac) ? ac : 9999; bool mock = f["mock"] == "true";
    var e = Db.Q("SELECT Id,FaceImage,Blocked FROM Employees WHERE Code=@c AND Active=1", ("@c", code)).FirstOrDefault();
    if (e == null || e["FaceImage"] == null) return Results.BadRequest("Not enrolled");
    var blk = Db.DeviceBlock(dev, e["Id"], true); if (blk != null) return Results.BadRequest(blk);
    if (Convert.ToInt64(e["Blocked"]) == 1) return Results.BadRequest("Your ID is blocked. Contact the admin.");
    var gq = Db.GpsQuality(e["Id"], acc, mock); if (gq != null) return Results.BadRequest(gq);
    if (f.Files.Count < 3) return Results.BadRequest("Please install the latest version of the app.");
    var loc = Db.Geofence(e["Id"], lat, lng, out var err);
    if (loc == null) return Results.BadRequest(err!.StartsWith("No location") ? err : $"You are {err}. Your position: {lat:F5}, {lng:F5}");
    int id = Convert.ToInt32(e["Id"]);
    var imgs = new List<byte[]>(); for (int i = 0; i < 3; i++) imgs.Add(await Db.Bytes(f.Files[i]));
    var a = FaceStore.AnalyzeBurst(imgs, out var aerr); if (a == null) return Results.BadRequest(aerr);
    var known = FaceStore.Get(id);
    if (known.Count == 0) return Results.BadRequest("Your saved photos are not usable. Ask the admin to reset your face.");
    var ds = a.Encs.Select(x => known.Min(k => FaceStore.Dist(k, x))).ToList();
    if (ds.Count(x => x <= 0.50) < 2) return Results.BadRequest($"Face did not match (difference {ds.Min():F2}, must be below 0.50). Face the camera in good light and try again.");
    var lv = Live.Decide(id, imgs, a); if (lv.code != 0) return lv.code == 409 ? Results.Conflict(lv.msg) : Results.BadRequest(lv.msg);
    var rp = Db.RepeatedPosition(e["Id"], lat, lng); if (rp != null) return Results.BadRequest(rp);
    Db.Q(Db.InsertAtt, ("@e", e["Id"]), ("@l", loc["Id"]), ("@t", DateTime.Now), ("@s", 1 - ds.Min()), ("@d", dev), ("@la", lat), ("@ln", lng), ("@ac", acc), ("@mo", a.Motion), ("@bl", a.Blink), ("@ph", lv.photoId == 0 ? (object)DBNull.Value : lv.photoId));
    return Results.Ok($"Attendance recorded at {loc["Name"]} - {DateTime.Now:dd MMM yyyy HH:mm}");
});
app.MapPost("/api/scan", async (HttpRequest req) => {
    var f = await req.ReadFormAsync(); var dev = f["deviceId"].ToString();
    double lat = double.Parse(f["lat"]!), lng = double.Parse(f["lng"]!);
    double acc = double.TryParse(f["acc"], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var ac) ? ac : 9999; bool mock = f["mock"] == "true";
    var d = Db.Q("SELECT d.OwnerEmployeeId, o.AllowOthers, CASE WHEN o.FaceImage IS NULL THEN 0 ELSE 1 END AS OwnerEnrolled FROM Devices d JOIN Employees o ON o.Id=d.OwnerEmployeeId WHERE d.DeviceId=@d", ("@d", dev)).FirstOrDefault();
    if (d == null || Convert.ToInt64(d["AllowOthers"]) == 0 || Convert.ToInt64(d["OwnerEnrolled"]) == 0) return Results.BadRequest("Face scan is only available on a supervisor's phone.");
    var gq = Db.GpsQuality(d["OwnerEmployeeId"], acc, mock); if (gq != null) return Results.BadRequest(gq);
    if (f.Files.Count < 3) return Results.BadRequest("Please install the latest version of the app.");
    if (!FaceStore.Ready) return Results.BadRequest("Face data is still loading. Try again in a minute.");
    var imgs = new List<byte[]>(); for (int i = 0; i < 3; i++) imgs.Add(await Db.Bytes(f.Files[i]));
    var a = FaceStore.AnalyzeBurst(imgs, out var aerr); if (a == null) return Results.BadRequest(aerr);
    var (id, best, second) = FaceStore.Identify(a.Encs, -1);
    if (id < 0 || best > 0.45) return Results.BadRequest("Face not recognised. Use the Employee ID instead.");
    if (second - best < 0.08) return Results.BadRequest("Not sure who this is. Use the Employee ID instead.");
    var e = Db.Q("SELECT Id,Name,Active,Blocked FROM Employees WHERE Id=@i", ("@i", id)).FirstOrDefault();
    if (e == null || Convert.ToInt64(e["Active"]) == 0) return Results.BadRequest("Employee is not active.");
    if (Convert.ToInt64(e["Blocked"]) == 1) return Results.BadRequest($"{e["Name"]}'s ID is blocked. Contact the admin.");
    var loc = Db.Geofence(e["Id"], lat, lng, out var err);
    if (loc == null) return Results.BadRequest($"{e["Name"]}: {err}");
    var lv = Live.Decide(id, imgs, a); if (lv.code != 0) return lv.code == 409 ? Results.Conflict(lv.msg) : Results.BadRequest(lv.msg);
    var rp = Db.RepeatedPosition(e["Id"], lat, lng); if (rp != null) return Results.BadRequest(rp);
    Db.Q(Db.InsertAtt, ("@e", e["Id"]), ("@l", loc["Id"]), ("@t", DateTime.Now), ("@s", 1 - best), ("@d", dev), ("@la", lat), ("@ln", lng), ("@ac", acc), ("@mo", a.Motion), ("@bl", a.Blink), ("@ph", lv.photoId == 0 ? (object)DBNull.Value : lv.photoId));
    return Results.Ok($"Attendance recorded for {e["Name"]} at {loc["Name"]} - {DateTime.Now:dd MMM yyyy HH:mm}");
});
app.MapGet("/api/checkins/flagged", () => Db.Q("SELECT TOP 100 c.Id, c.Time, c.Status, c.Motion, c.Blink, e.Code, e.Name FROM CheckinPhotos c LEFT JOIN Employees e ON e.Id=c.EmployeeId WHERE c.Status <> 'ok' ORDER BY c.Id DESC"));
app.MapGet("/api/checkins/{id}/photo/{n}", (int id, int n) => {
    var r = Db.Q($"SELECT Img{Math.Clamp(n, 1, 3)} AS Img FROM CheckinPhotos WHERE Id=@i", ("@i", id)).FirstOrDefault();
    return r?["Img"] is byte[] b && b.Length > 0 ? Results.File(b, "image/jpeg") : Results.NotFound("Photo not available (photos are kept for 30 days).");
});
app.MapGet("/api/lookalikes", () => {
    if (!FaceStore.Ready) return Results.BadRequest("Face data is still loading. Try again in a minute.");
    var ids = FaceStore.Ids(); var names = Db.Q("SELECT Id,Code,Name FROM Employees").ToDictionary(r => Convert.ToInt32(r["Id"]), r => r["Code"] + " - " + r["Name"]);
    var res = new List<(string a, string b, double d)>();
    for (int i = 0; i < ids.Count; i++) for (int j = i + 1; j < ids.Count; j++) {
        double d = double.MaxValue;
        foreach (var x in FaceStore.Get(ids[i])) foreach (var y in FaceStore.Get(ids[j])) d = Math.Min(d, FaceStore.Dist(x, y));
        if (d < 0.6) res.Add((names.GetValueOrDefault(ids[i], "?"), names.GetValueOrDefault(ids[j], "?"), Math.Round(d, 2)));
    }
    return Results.Ok(res.OrderBy(x => x.d).Select(x => new { a = x.a, b = x.b, difference = x.d }));
});
app.Run();

record Emp(string? Code, string Name, string? Department, bool Active);
record Loc(string Name, double Lat, double Lng);
record LoginReq(string Code, string? DeviceId, bool AsOwner);

static class Db {
    public const double DefaultRadius = 100; // metres, applied to every new location
    public const string InsertAtt = "INSERT INTO Attendance(EmployeeId,LocationId,Time,Similarity,DeviceId,DeviceOwnerId,Lat,Lng,Accuracy,Motion,Blink,CheckinPhotoId) VALUES(@e,@l,@t,@s,@d,(SELECT OwnerEmployeeId FROM Devices WHERE DeviceId=@d),@la,@ln,@ac,@mo,@bl,@ph)";
    public static string Cs = "";
    public static List<Dictionary<string, object?>> Q(string sql, params (string, object?)[] p) {
        using var c = new SqlConnection(Cs); c.Open();
        var cmd = c.CreateCommand(); cmd.CommandText = sql;
        foreach (var (k, v) in p) cmd.Parameters.AddWithValue(k, v ?? DBNull.Value);
        var rows = new List<Dictionary<string, object?>>();
        using var r = cmd.ExecuteReader();
        while (r.Read()) { var d = new Dictionary<string, object?>();
            for (int i = 0; i < r.FieldCount; i++) d[r.GetName(i)] = r.IsDBNull(i) ? null : r.GetValue(i);
            rows.Add(d); }
        return rows;
    }
    public static Dictionary<string, object?>? Geofence(object? empId, double lat, double lng, out string? err) {
        err = null;
        var locs = Q("SELECT l.* FROM Locations l JOIN EmployeeLocations el ON el.LocationId=l.Id WHERE el.EmployeeId=@e", ("@e", empId));
        if (locs.Count == 0) { err = "No location is assigned. Ask the admin."; return null; }
        var hit = locs.FirstOrDefault(l => Dist(lat, lng, (double)l["Lat"]!, (double)l["Lng"]!) <= (double)l["RadiusM"]!);
        if (hit == null) err = $"{locs.Min(l => Dist(lat, lng, (double)l["Lat"]!, (double)l["Lng"]!)):F0} m from the nearest assigned location (must be within 100 m)";
        return hit;
    }
    public static void Alert(object? empId, string kind, string detail) =>
        Q("INSERT INTO Alerts(EmployeeId,Time,Kind,Detail) VALUES(@e,SYSDATETIME(),@k,@d)", ("@e", empId), ("@k", kind), ("@d", detail));
    // Fake GPS apps and weak signals are refused.
    public static string? GpsQuality(object? empId, double acc, bool mock) {
        if (mock) { Alert(empId, "Fake location", "A mock (fake) GPS location was detected on the phone."); return "Fake GPS detected. Turn off any fake-location app and try again. The admin has been notified."; }
        if (acc > 50) return $"GPS signal is too weak (accuracy {acc:F0} m). Move to an open area and try again.";
        return null;
    }
    // Real GPS never repeats to the last digit: the same exact position 3 times in a row blocks the ID.
    public static string? RepeatedPosition(object? empId, double lat, double lng) {
        var last = Q("SELECT TOP 2 Lat, Lng FROM Attendance WHERE EmployeeId=@e AND Lat IS NOT NULL ORDER BY Id DESC", ("@e", empId));
        if (last.Count == 2 && last.All(r => Math.Abs((double)r["Lat"]! - lat) < 1e-7 && Math.Abs((double)r["Lng"]! - lng) < 1e-7)) {
            Q("UPDATE Employees SET Blocked=1, BlockReason=@r, BlockedAt=SYSDATETIME() WHERE Id=@e", ("@r", "Same exact GPS position 3 times in a row"), ("@e", empId));
            Alert(empId, "Blocked", $"The exact same GPS position ({lat:F6}, {lng:F6}) was reported 3 times in a row. ID blocked.");
            return "Your ID has been blocked: the same exact GPS position was reported 3 times in a row. Contact the admin.";
        }
        return null;
    }
    public static bool IsLan(System.Net.IPAddress? ip) {
        if (ip == null) return false;
        if (ip.IsIPv4MappedToIPv6) ip = ip.MapToIPv4();
        if (System.Net.IPAddress.IsLoopback(ip)) return true;
        var b = ip.GetAddressBytes();
        if (b.Length == 4) return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168);
        return ip.IsIPv6LinkLocal || (b[0] & 0xFE) == 0xFC;
    }
    // Returns a reason if this phone may not be used by this employee, otherwise null.
    public static string? DeviceBlock(string? dev, object? empId, bool empEnrolled) {
        if (string.IsNullOrEmpty(dev)) return null;
        var d = Q("SELECT d.OwnerEmployeeId, o.AllowOthers, o.RegisteredDeviceId, CASE WHEN o.FaceImage IS NULL THEN 0 ELSE 1 END AS OwnerEnrolled FROM Devices d JOIN Employees o ON o.Id=d.OwnerEmployeeId WHERE d.DeviceId=@d", ("@d", dev)).FirstOrDefault();
        if (d == null) return null;
        if (Convert.ToInt32(d["OwnerEmployeeId"]) == Convert.ToInt32(empId)) {
            var reg = d["RegisteredDeviceId"] as string;
            return !string.IsNullOrEmpty(reg) && reg != dev ? "Your face is registered on another phone. Ask the admin to reset it." : null;
        }
        if (Convert.ToInt64(d["OwnerEnrolled"]) == 0) return "The owner of this phone must register their face first.";
        if (Convert.ToInt64(d["AllowOthers"]) == 0) return "This phone is locked: it can only mark its owner's attendance. Use your own phone or a supervisor's phone.";
        if (!empEnrolled) return "Your face is not registered yet. Register on your own phone first.";
        return null;
    }
    public static async Task<byte[]> Bytes(IFormFile f) { using var m = new MemoryStream(); await f.CopyToAsync(m); return m.ToArray(); }
    public static double Dist(double a, double b, double c, double d) {
        double R = 6371000; double r(double x) => x * Math.PI / 180;
        double dl = r(c - a), dg = r(d - b);
        double h = Math.Sin(dl / 2) * Math.Sin(dl / 2) + Math.Cos(r(a)) * Math.Cos(r(c)) * Math.Sin(dg / 2) * Math.Sin(dg / 2);
        return 2 * R * Math.Asin(Math.Sqrt(h));
    }
}

static class Face {
    // Phone cameras often save photos sideways with a rotation tag; turn them upright so the face can be found.
    public static byte[] Upright(byte[] jpg) {
        try {
            using var ms = new MemoryStream(jpg);
            using var img = System.Drawing.Image.FromStream(ms);
            const int tag = 0x0112;
            if (!img.PropertyIdList.Contains(tag)) return jpg;
            var rf = img.GetPropertyItem(tag)!.Value![0] switch {
                2 => System.Drawing.RotateFlipType.RotateNoneFlipX, 3 => System.Drawing.RotateFlipType.Rotate180FlipNone,
                4 => System.Drawing.RotateFlipType.RotateNoneFlipY, 5 => System.Drawing.RotateFlipType.Rotate90FlipX,
                6 => System.Drawing.RotateFlipType.Rotate90FlipNone, 7 => System.Drawing.RotateFlipType.Rotate270FlipX,
                8 => System.Drawing.RotateFlipType.Rotate270FlipNone, _ => System.Drawing.RotateFlipType.RotateNoneFlipNone };
            if (rf == System.Drawing.RotateFlipType.RotateNoneFlipNone) return jpg;
            img.RotateFlip(rf); img.RemovePropertyItem(tag);
            using var outMs = new MemoryStream(); img.Save(outMs, System.Drawing.Imaging.ImageFormat.Jpeg); return outMs.ToArray();
        } catch { return jpg; }
    }
    public static FaceEncoding? Encode(FaceRecognition fr, byte[] jpg, out int count) {
        var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".jpg");
        File.WriteAllBytes(tmp, Upright(jpg));
        try { using var img = FaceRecognition.LoadImageFile(tmp); var l = fr.FaceEncodings(img).ToList(); count = l.Count; return count == 1 ? l[0] : null; }
        finally { File.Delete(tmp); }
    }
}

// Keeps every registered face in memory so identification is fast.
static class FaceStore {
    static readonly object Lock = new();
    static readonly Dictionary<int, List<FaceEncoding>> enc = new();
    static FaceRecognition Fr = null!;
    public static volatile bool Ready;
    public static void Init(FaceRecognition fr) { Fr = fr; Task.Run(() => {
        foreach (var r in Db.Q("SELECT Id FROM Employees WHERE FaceImage IS NOT NULL")) { try { Get(Convert.ToInt32(r["Id"])); } catch { } }
        Ready = true; }); }
    public static FaceEncoding? EncodeSafe(byte[] b, out int n) { lock (Lock) { return Face.Encode(Fr, b, out n); } }
    public static List<FaceEncoding> Get(int empId) {
        lock (Lock) { if (enc.TryGetValue(empId, out var cached)) return cached; }
        var list = new List<FaceEncoding>();
        var rows = Db.Q("SELECT Image FROM EmployeeFaces WHERE EmployeeId=@e", ("@e", empId));
        if (rows.Count == 0) rows = Db.Q("SELECT FaceImage AS Image FROM Employees WHERE Id=@e AND FaceImage IS NOT NULL", ("@e", empId));
        foreach (var r in rows) { var fe = EncodeSafe((byte[])r["Image"]!, out int n); if (fe != null) list.Add(fe); }
        lock (Lock) { enc[empId] = list; }
        return list;
    }
    public static void Set(int id, List<FaceEncoding> l) { lock (Lock) { enc[id] = l; } }
    public static void Remove(int id) { lock (Lock) { enc.Remove(id); } }
    public static List<int> Ids() { lock (Lock) { return enc.Keys.ToList(); } }
    public static double Dist(FaceEncoding a, FaceEncoding b) { lock (Lock) { return FaceRecognition.FaceDistance(a, b); } }
    // Distance between the eye centres, from a flattened landmark set (order: chin 17, brows 5+5, nose 4+5, left eye 6, right eye 6, lips).
    public static double Iod(double[] v) {
        double lx = 0, ly = 0, rx = 0, ry = 0; int l0 = 17 + 5 + 5 + 4 + 5, r0 = l0 + 6;
        for (int i = 0; i < 6; i++) { lx += v[2 * (l0 + i)]; ly += v[2 * (l0 + i) + 1]; rx += v[2 * (r0 + i)]; ry += v[2 * (r0 + i) + 1]; }
        return Math.Sqrt(((lx - rx) * (lx - rx) + (ly - ry) * (ly - ry))) / 6;
    }
    public record Burst(List<FaceEncoding> Encs, List<double[]> Lms, double Motion, double Blink);
    // Face points are read without naming the library's point type, so this works with older and newer library versions.
    static double Num(object o, string n) { var ty = o.GetType(); var pi = ty.GetProperty(n); return Convert.ToDouble(pi != null ? pi.GetValue(o) : ty.GetField(n)!.GetValue(o)); }
    static (double x, double y)[] Pts(System.Collections.IEnumerable ps) {
        var l = new List<(double, double)>();
        foreach (var p in ps) { var inner = p.GetType().GetProperty("Point")?.GetValue(p) ?? p; l.Add((Num(inner, "X"), Num(inner, "Y"))); }
        return l.ToArray();
    }
    static double Dst((double x, double y) a, (double x, double y) b) { double dx = a.x - b.x, dy = a.y - b.y; return Math.Sqrt(dx * dx + dy * dy); }
    static double Ear((double x, double y)[] q) => (Dst(q[1], q[5]) + Dst(q[2], q[4])) / (2 * Dst(q[0], q[3]));
    // Reads 3 pictures: faces, landmark points, how much the face changed (motion) and how much the eyes opened/closed (blink).
    public static Burst? AnalyzeBurst(List<byte[]> imgs, out string? err) {
        err = null; var encs = new List<FaceEncoding>(); var lms = new List<double[]>(); var ears = new List<double>(); double iod = 0;
        lock (Lock) {
            for (int i = 0; i < imgs.Count; i++) {
                var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".jpg");
                File.WriteAllBytes(tmp, Face.Upright(imgs[i]));
                try {
                    using var img = FaceRecognition.LoadImageFile(tmp);
                    var locs = Fr.FaceLocations(img).ToList();
                    if (locs.Count != 1) { err = $"Picture {i + 1}: no single clear face found. Try again in good light."; return null; }
                    encs.Add(Fr.FaceEncodings(img, locs).First());
                    var lm = Fr.FaceLandmark(img, locs).First();
                    var v = new List<double>();
                    foreach (var part in new[] { FacePart.Chin, FacePart.LeftEyebrow, FacePart.RightEyebrow, FacePart.NoseBridge, FacePart.NoseTip, FacePart.LeftEye, FacePart.RightEye, FacePart.TopLip, FacePart.BottomLip })
                        foreach (var q in Pts(lm[part])) { v.Add(q.x); v.Add(q.y); }
                    var le = Pts(lm[FacePart.LeftEye]); var re = Pts(lm[FacePart.RightEye]);
                    ears.Add((Ear(le) + Ear(re)) / 2); lms.Add(v.ToArray());
                    if (i == 0) { double lx = le.Average(p => p.x), ly = le.Average(p => p.y), rx = re.Average(p => p.x), ry = re.Average(p => p.y); iod = Math.Sqrt((lx - rx) * (lx - rx) + (ly - ry) * (ly - ry)); }
                } finally { File.Delete(tmp); }
            }
        }
        for (int i = 0; i < encs.Count; i++) for (int j = i + 1; j < encs.Count; j++)
            if (Dist(encs[i], encs[j]) > 0.45) { err = "The pictures do not look like the same person. Try again."; return null; }
        double motion = 0;
        for (int i = 0; i < lms.Count; i++) for (int j = i + 1; j < lms.Count; j++) motion = Math.Max(motion, Live.Residual(lms[i], lms[j]) / iod);
        return new Burst(encs, lms, motion, ears.Max() - ears.Min());
    }
    public static (int id, double best, double second) Identify(List<FaceEncoding> probes, int exclude) {
        int bid = -1; double best = double.MaxValue, second = double.MaxValue;
        foreach (var id in Ids()) {
            if (id == exclude) continue;
            var l = Get(id); if (l.Count == 0) continue;
            double d = double.MaxValue;
            foreach (var k in l) foreach (var p in probes) d = Math.Min(d, Dist(k, p));
            if (d < best) { second = best; best = d; bid = id; } else if (d < second) second = d;
        }
        return (bid, best, second);
    }
}

// Decides whether the 3 pictures show a live face. Thresholds can be changed in appsettings.json ("Liveness").
static class Live {
    public static IConfiguration? Config;
    static double Cfg(string k, double d) => double.TryParse(Config?[k], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var v) ? v : d;
    // How different two faces are after removing simple sliding, tilting and resizing (a flat photo only does those).
    public static double Residual(double[] a, double[] b) {
        int n = a.Length / 2; double ax = 0, ay = 0, bx = 0, by = 0;
        for (int i = 0; i < n; i++) { ax += a[2 * i]; ay += a[2 * i + 1]; bx += b[2 * i]; by += b[2 * i + 1]; }
        ax /= n; ay /= n; bx /= n; by /= n;
        double re = 0, im = 0, nb = 0;
        for (int i = 0; i < n; i++) { double x1 = a[2 * i] - ax, y1 = a[2 * i + 1] - ay, x2 = b[2 * i] - bx, y2 = b[2 * i + 1] - by; re += x1 * x2 + y1 * y2; im += y1 * x2 - x1 * y2; nb += x2 * x2 + y2 * y2; }
        double zr = re / nb, zi = im / nb, sum = 0;
        for (int i = 0; i < n; i++) { double x1 = a[2 * i] - ax, y1 = a[2 * i + 1] - ay, x2 = b[2 * i] - bx, y2 = b[2 * i + 1] - by; double dx = x1 - (zr * x2 - zi * y2), dy = y1 - (zi * x2 + zr * y2); sum += dx * dx + dy * dy; }
        return Math.Sqrt(sum / n);
    }
    static byte[] Pack(double[] d) { var b = new byte[d.Length * 8]; Buffer.BlockCopy(d, 0, b, 0, b.Length); return b; }
    static double[] Unpack(byte[] b) { var d = new double[b.Length / 8]; Buffer.BlockCopy(b, 0, d, 0, b.Length); return d; }
    static int Save(int empId, string status, FaceStore.Burst a, List<byte[]> imgs) {
        byte[] I(int i) => i < imgs.Count ? imgs[i] : Array.Empty<byte>();
        var r = Db.Q("INSERT INTO CheckinPhotos(EmployeeId,Time,Status,Motion,Blink,Img1,Img2,Img3,Feat) VALUES(@e,SYSDATETIME(),@s,@m,@b,@i1,@i2,@i3,@f); SELECT SCOPE_IDENTITY() AS Id",
            ("@e", empId), ("@s", status), ("@m", a.Motion), ("@b", a.Blink), ("@i1", I(0)), ("@i2", I(1)), ("@i3", I(2)), ("@f", Pack(a.Lms[1])));
        return Convert.ToInt32(r[0]["Id"]);
    }
    // code 0 = accept, 409 = ask the person to try again, 400 = refuse
    public static (int code, string? msg, int photoId) Decide(int empId, List<byte[]> imgs, FaceStore.Burst a) {
        double minMotion = Cfg("Liveness:MinMotion", 0.012), minBlink = Cfg("Liveness:MinBlink", 0.06);
        bool live = a.Motion >= minMotion || a.Blink >= minBlink;
        if (live || Cfg("Liveness:Enforce", 1) == 0) return (0, null, Save(empId, "ok", a, new List<byte[]> { imgs[1] }));
        var prev = Db.Q("SELECT TOP 1 Id, Feat FROM CheckinPhotos WHERE EmployeeId=@e AND Status='retry' AND Time > DATEADD(minute,-10,SYSDATETIME()) ORDER BY Id DESC", ("@e", empId)).FirstOrDefault();
        if (prev == null) { Save(empId, "retry", a, imgs); return (409, "No movement was detected. Please try again: look at the screen and blink once.", 0); }
        Db.Q("UPDATE CheckinPhotos SET Status='retry-used' WHERE Id=@i", ("@i", prev["Id"]));
        double change = Residual(Unpack((byte[])prev["Feat"]!), a.Lms[1]) / Math.Max(1e-6, FaceStore.Iod(a.Lms[1]));
        if (change >= minMotion) return (0, null, Save(empId, "ok", a, new List<byte[]> { imgs[1] }));
        Save(empId, "refused", a, imgs);
        Db.Alert(empId, "Photo suspected", $"The camera saw a still picture twice in a row (movement {a.Motion:F3}, eyes {a.Blink:F3}). Check-in not recorded.");
        var n = Convert.ToInt32(Db.Q("SELECT COUNT(*) AS C FROM CheckinPhotos WHERE EmployeeId=@e AND Status='refused' AND Time > DATEADD(hour,-24,SYSDATETIME())", ("@e", empId))[0]["C"]);
        if (n >= 3) {
            Db.Q("UPDATE Employees SET Blocked=1, BlockReason=@r, BlockedAt=SYSDATETIME() WHERE Id=@e", ("@r", "Still picture used 3 times in 24 hours"), ("@e", empId));
            Db.Alert(empId, "Blocked", "A still picture was used for check-in 3 times in 24 hours. ID blocked.");
            return (400, "Your ID has been blocked: still pictures were used for check-in. Contact the admin.", 0);
        }
        return (400, "Attendance not recorded: the camera sees a still picture, not a live face. The admin has been notified.", 0);
    }
}
