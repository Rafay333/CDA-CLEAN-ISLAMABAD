using System.Text.Json;
using FaceRecognitionDotNet;

// Same face engine and photo rules as AttendanceSystem\Server\Program.cs.
// This process only reads the model files. It does not change that project.
var models = Environment.GetEnvironmentVariable("FACE_MODELS");
if (string.IsNullOrWhiteSpace(models) || !Directory.Exists(models))
{
    Console.WriteLine(JsonSerializer.Serialize(new { ready = false, error = "Face models were not found. Set FACE_MODELS to the AttendanceSystem Server\\models folder." }));
    return;
}

FaceRecognition fr;
try { fr = FaceRecognition.Create(models); }
catch (Exception ex)
{
    Console.WriteLine(JsonSerializer.Serialize(new { ready = false, error = "Could not load face models. " + ex.Message }));
    return;
}
Console.WriteLine(JsonSerializer.Serialize(new { ready = true }));
Console.Out.Flush();

string? line;
while ((line = Console.ReadLine()) != null)
{
    if (line.Length == 0) continue;
    int id = 0;
    try
    {
        using var doc = JsonDocument.Parse(line);
        var root = doc.RootElement;
        id = root.GetProperty("id").GetInt32();
        var op = root.GetProperty("op").GetString();
        if (op == "encode")
        {
            var raw = Encode(fr, root.GetProperty("path").GetString()!, out var count, out var problem);
            Write(new { id, count, encoding = raw, error = problem });
        }
        else if (op == "burst")
        {
            var paths = root.GetProperty("paths").EnumerateArray().Select(x => x.GetString()!).ToList();
            var burst = Burst(fr, paths, out var error);
            if (burst == null) Write(new { id, ok = false, error });
            else Write(new { id, ok = true, encodings = burst.Value.encodings, feat = burst.Value.feat, motion = burst.Value.motion, blink = burst.Value.blink });
        }
        else Write(new { id, ok = false, error = "Unknown face operation." });
    }
    catch (Exception ex)
    {
        Write(new { id, ok = false, error = ex.Message });
    }
}

static void Write(object value)
{
    Console.WriteLine(JsonSerializer.Serialize(value));
    Console.Out.Flush();
}

static double[]? Encode(FaceRecognition fr, string path, out int count, out string? problem)
{
    count = 0;
    problem = null;
    var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".jpg");
    try
    {
        File.WriteAllBytes(tmp, Upright(File.ReadAllBytes(path)));
        using var img = FaceRecognition.LoadImageFile(tmp);
        var found = fr.FaceEncodings(img).ToList();
        count = found.Count;
        if (count != 1) { foreach (var face in found) Done(face); return null; }
        try { return Raw(found[0]); }
        finally { Done(found[0]); }
    }
    catch (Exception ex)
    {
        // A photo dlib cannot read counts as "no face"; anything after detection is a real fault.
        problem = count == 1 ? ex.Message : null;
        return null;
    }
    finally { try { File.Delete(tmp); } catch { } }
}

static (List<double[]> encodings, double[] feat, double motion, double blink)? Burst(FaceRecognition fr, List<string> paths, out string? error)
{
    error = null;
    var encodings = new List<double[]>();
    var landmarks = new List<double[]>();
    var ears = new List<double>();
    double iod = 0;
    for (int i = 0; i < paths.Count; i++)
    {
        var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".jpg");
        var detected = false;
        try
        {
            File.WriteAllBytes(tmp, Upright(File.ReadAllBytes(paths[i])));
            using var img = FaceRecognition.LoadImageFile(tmp);
            var locs = fr.FaceLocations(img).ToList();
            if (locs.Count != 1) { error = $"Picture {i + 1}: no single clear face found. Try again in good light."; return null; }
            detected = true;
            var enc = fr.FaceEncodings(img, locs).First();
            encodings.Add(Raw(enc));
            Done(enc);
            var lm = fr.FaceLandmark(img, locs).First();
            var flat = new List<double>();
            foreach (var part in new[] { FacePart.Chin, FacePart.LeftEyebrow, FacePart.RightEyebrow, FacePart.NoseBridge, FacePart.NoseTip, FacePart.LeftEye, FacePart.RightEye, FacePart.TopLip, FacePart.BottomLip })
                foreach (var q in Pts(lm[part])) { flat.Add(q.x); flat.Add(q.y); }
            var le = Pts(lm[FacePart.LeftEye]);
            var re = Pts(lm[FacePart.RightEye]);
            ears.Add((Ear(le) + Ear(re)) / 2);
            landmarks.Add(flat.ToArray());
            if (i == 0)
            {
                double lx = le.Average(p => p.x), ly = le.Average(p => p.y), rx = re.Average(p => p.x), ry = re.Average(p => p.y);
                iod = Math.Sqrt((lx - rx) * (lx - rx) + (ly - ry) * (ly - ry));
            }
        }
        catch (Exception ex)
        {
            error = detected
                ? "Face recognition failed: " + ex.Message
                : $"Picture {i + 1}: no single clear face found. Try again in good light.";
            return null;
        }
        finally { try { File.Delete(tmp); } catch { } }
    }
    for (int i = 0; i < encodings.Count; i++)
        for (int j = i + 1; j < encodings.Count; j++)
            if (Dist(encodings[i], encodings[j]) > 0.45) { error = "The pictures do not look like the same person. Try again."; return null; }
    double motion = 0;
    for (int i = 0; i < landmarks.Count; i++)
        for (int j = i + 1; j < landmarks.Count; j++)
            motion = Math.Max(motion, Residual(landmarks[i], landmarks[j]) / Math.Max(iod, 1e-6));
    return (encodings, landmarks.Count > 1 ? landmarks[1] : landmarks[0], motion, ears.Max() - ears.Min());
}

static double Dist(double[] a, double[] b)
{
    double sum = 0;
    for (int i = 0; i < a.Length; i++) { double d = a[i] - b[i]; sum += d * d; }
    return Math.Sqrt(sum);
}

static double Residual(double[] a, double[] b)
{
    int n = a.Length / 2;
    double ax = 0, ay = 0, bx = 0, by = 0;
    for (int i = 0; i < n; i++) { ax += a[2 * i]; ay += a[2 * i + 1]; bx += b[2 * i]; by += b[2 * i + 1]; }
    ax /= n; ay /= n; bx /= n; by /= n;
    double re = 0, im = 0, nb = 0;
    for (int i = 0; i < n; i++)
    {
        double x1 = a[2 * i] - ax, y1 = a[2 * i + 1] - ay, x2 = b[2 * i] - bx, y2 = b[2 * i + 1] - by;
        re += x1 * x2 + y1 * y2; im += y1 * x2 - x1 * y2; nb += x2 * x2 + y2 * y2;
    }
    double zr = re / nb, zi = im / nb, sum = 0;
    for (int i = 0; i < n; i++)
    {
        double x1 = a[2 * i] - ax, y1 = a[2 * i + 1] - ay, x2 = b[2 * i] - bx, y2 = b[2 * i + 1] - by;
        double dx = x1 - (zr * x2 - zi * y2), dy = y1 - (zi * x2 + zr * y2);
        sum += dx * dx + dy * dy;
    }
    return Math.Sqrt(sum / n);
}

static double[] Raw(object face)
{
    const System.Reflection.BindingFlags any = System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance;
    var type = face.GetType();

    // Newer FaceRecognitionDotNet builds expose the numbers directly.
    var direct = type.GetMethod("GetRawEncoding", any);
    if (direct != null && direct.Invoke(face, null) is double[] fromMethod && fromMethod.Length > 0) return fromMethod;

    // 1.2.3.x keeps a DlibDotNet Matrix<double> in an internal "Encoding" property.
    var matrix = type.GetProperty("Encoding", any)?.GetValue(face);
    if (matrix != null)
    {
        var toArray = matrix.GetType().GetMethod("ToArray", Type.EmptyTypes);
        if (toArray?.Invoke(matrix, null) is double[] fromMatrix && fromMatrix.Length > 0) return fromMatrix;
    }

    // Last resort: the class is ISerializable and writes "Encoding" as double[].
    if (face is System.Runtime.Serialization.ISerializable serializable)
    {
        var info = new System.Runtime.Serialization.SerializationInfo(type, new System.Runtime.Serialization.FormatterConverter());
        serializable.GetObjectData(info, new System.Runtime.Serialization.StreamingContext());
        if (info.GetValue("Encoding", typeof(double[])) is double[] fromInfo && fromInfo.Length > 0) return fromInfo;
    }

    throw new InvalidOperationException("This face library cannot export an encoding.");
}

static void Done(object face) { if (face is IDisposable disposable) disposable.Dispose(); }

static byte[] Upright(byte[] jpg)
{
    try
    {
        using var ms = new MemoryStream(jpg);
        using var img = System.Drawing.Image.FromStream(ms);
        const int tag = 0x0112;
        if (!img.PropertyIdList.Contains(tag)) return jpg;
        var turn = img.GetPropertyItem(tag)!.Value![0] switch
        {
            2 => System.Drawing.RotateFlipType.RotateNoneFlipX,
            3 => System.Drawing.RotateFlipType.Rotate180FlipNone,
            4 => System.Drawing.RotateFlipType.RotateNoneFlipY,
            5 => System.Drawing.RotateFlipType.Rotate90FlipX,
            6 => System.Drawing.RotateFlipType.Rotate90FlipNone,
            7 => System.Drawing.RotateFlipType.Rotate270FlipX,
            8 => System.Drawing.RotateFlipType.Rotate270FlipNone,
            _ => System.Drawing.RotateFlipType.RotateNoneFlipNone
        };
        if (turn == System.Drawing.RotateFlipType.RotateNoneFlipNone) return jpg;
        img.RotateFlip(turn);
        img.RemovePropertyItem(tag);
        using var output = new MemoryStream();
        img.Save(output, System.Drawing.Imaging.ImageFormat.Jpeg);
        return output.ToArray();
    }
    catch { return jpg; }
}

static double Num(object o, string name)
{
    var type = o.GetType();
    var prop = type.GetProperty(name);
    return Convert.ToDouble(prop != null ? prop.GetValue(o) : type.GetField(name)!.GetValue(o));
}

static (double x, double y)[] Pts(System.Collections.IEnumerable points)
{
    var list = new List<(double, double)>();
    foreach (var point in points)
    {
        var inner = point.GetType().GetProperty("Point")?.GetValue(point) ?? point;
        list.Add((Num(inner, "X"), Num(inner, "Y")));
    }
    return list.ToArray();
}

static double Span((double x, double y) a, (double x, double y) b)
{
    double dx = a.x - b.x, dy = a.y - b.y;
    return Math.Sqrt(dx * dx + dy * dy);
}

static double Ear((double x, double y)[] eye) => (Span(eye[1], eye[5]) + Span(eye[2], eye[4])) / (2 * Span(eye[0], eye[3]));
