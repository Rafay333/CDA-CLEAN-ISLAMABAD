import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// The server sends messages as JSON text; this removes the quote marks.
String clean(String s) { try { final d = jsonDecode(s); if (d is String) return d; } catch (_) {} return s; }

// Address of the IIS server
const String lanServer = 'http://192.168.0.201:5500';       // inside the office
const String publicServer = 'http://115.186.146.205:5500';  // from mobile data / outside
String server = lanServer;

// Uses the office address when reachable, otherwise the public address.
Future<void> pickServer() async {
  Future<bool> reach(String s, int secs) async {
    try { await http.get(Uri.parse(s)).timeout(Duration(seconds: secs)); return true; } catch (_) { return false; }
  }
  final lan = reach(lanServer, 2), pub = reach(publicServer, 6);   // both start together
  if (await lan) { server = lanServer; return; }
  if (await pub) server = publicServer;
}
const String brand = 'Capital Development Authority';
const Color navy = Color(0xFF0B2A4A), accent = Color(0xFF1E88E5);

void main() => runApp(MaterialApp(
      title: brand,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: accent),
          scaffoldBackgroundColor: const Color(0xFFF2F6FB)),
      home: const App(),
    ));

class App extends StatefulWidget { const App({super.key}); @override State<App> createState() => _S(); }

class _S extends State<App> {
  final idCtl = TextEditingController();
  late SharedPreferences prefs;
  String deviceId = '';
  String? ownerCode, ownerName;   // employee who owns this phone
  String? code, name;         // employee currently using the app
  bool? enrolled; bool busy = false, ready = false, good = false; String msg = '';
  bool ownerAllows = false, retry = false;
  String busyText = 'Please wait...';
  Future<void>? conn;   // may other people mark attendance on this phone?

  @override
  void initState() { super.initState(); init(); }

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString('deviceId') ??
        List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16)).join();
    await prefs.setString('deviceId', deviceId);
    ownerCode = prefs.getString('owner');
    ownerName = prefs.getString('ownerName');
    setState(() => ready = true);            // show the app at once...
    conn = pickServer();                      // ...and connect in the background
    if (ownerCode != null) await login(ownerCode!);
  }

  Future<List<XFile>?> shots(int n, String title, {bool burst = false}) =>
      Navigator.of(context).push<List<XFile>>(MaterialPageRoute(builder: (_) => SelfieScreen(title: title, shots: n, burst: burst)));

  Future<XFile?> selfie([String title = 'Face scan']) async => (await shots(1, title))?.first;

  Future<void> run(Future<void> Function() job) async {
    setState(() { busy = true; msg = ''; good = false; retry = false; });
    try { await job(); } catch (e) {
      msg = e is TimeoutException ? 'This is taking too long (network or GPS). Please try again.' : 'Cannot reach the server. Check your internet and try again.';
      conn = pickServer();
    }
    setState(() => busy = false);
  }

  Future<void> login(String c) => run(() async {
    setState(() => busyText = 'Connecting to server...');
    await conn;
    final asOwner = ownerCode == null;
    final r = await http.post(Uri.parse('$server/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': c, 'deviceId': deviceId, 'asOwner': asOwner})).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) { msg = clean(r.body); return; }
    final d = jsonDecode(r.body);
    code = c; name = d['name']; enrolled = d['enrolled'];
    if (asOwner || c == ownerCode) ownerAllows = d['allowOthers'] == true;
    if (asOwner) { ownerCode = c; ownerName = name; await prefs.setString('owner', c); await prefs.setString('ownerName', name ?? ''); }
  });

  Future<http.Response> send(String path, XFile img, Map<String, String> fields) async {
    final req = http.MultipartRequest('POST', Uri.parse('$server$path'))
      ..fields.addAll({...fields, 'code': code!, 'deviceId': deviceId})
      ..files.add(http.MultipartFile.fromBytes('image', await img.readAsBytes(), filename: 'face.jpg'));
    return http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
  }

  Future<http.Response> sendMany(String path, List<XFile> imgs, Map<String, String> fields) async {
    final rq = http.MultipartRequest('POST', Uri.parse('$server$path'))..fields.addAll({...fields, 'code': code!, 'deviceId': deviceId});
    for (var i = 0; i < imgs.length; i++) { rq.files.add(http.MultipartFile.fromBytes('image$i', await imgs[i].readAsBytes(), filename: 'face$i.jpg')); }
    return http.Response.fromStream(await rq.send().timeout(const Duration(seconds: 90)));
  }

  Future<void> enroll() => run(() async {
    final imgs = await shots(3, 'Registration'); if (imgs == null) return;
    final rq = http.MultipartRequest('POST', Uri.parse('$server/api/enroll'))..fields.addAll({'code': code!, 'deviceId': deviceId});
    for (var i = 0; i < 3; i++) { rq.files.add(http.MultipartFile.fromBytes('image$i', await imgs[i].readAsBytes(), filename: 'face$i.jpg')); }
    setState(() => busyText = 'Checking your three photos... this can take up to a minute');
    final r = await http.Response.fromStream(await rq.send().timeout(const Duration(seconds: 90)));
    msg = clean(r.body); good = r.statusCode == 200;
    if (good) { if (code != ownerCode) { backToOwner('Face registered for $name.'); } else { enrolled = true; } }
  });

  Future<void> checkIn() => run(() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) { msg = 'Location permission needed'; return; }
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
    if (pos.accuracy > 50) { msg = 'GPS signal is too weak (accuracy ${pos.accuracy.round()} m). Move to an open area and try again.'; return; }
    final imgs = await shots(3, 'Check-in', burst: true); if (imgs == null) return;
    if (imgs.length < 3) { msg = 'The camera could not take all the pictures. Please try again.'; return; }
    setState(() => busyText = 'Checking location and face...');
    final r = await sendMany('/api/checkin', imgs, {'lat': '${pos.latitude}', 'lng': '${pos.longitude}', 'acc': '${pos.accuracy}', 'mock': '${pos.isMocked}'});
    msg = clean(r.body); good = r.statusCode == 200; retry = r.statusCode == 409;
    if (good && code != ownerCode) backToOwner('${name ?? ''}: ${clean(r.body)}');
  });

  // After helping someone else, go straight back to the phone owner's screen.
  void backToOwner(String m) { code = ownerCode; name = ownerName; enrolled = true; msg = m; good = true; }

  Future<void> scanFace() => run(() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) { msg = 'Location permission needed'; return; }
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
    if (pos.accuracy > 50) { msg = 'GPS signal is too weak (accuracy ${pos.accuracy.round()} m). Move to an open area and try again.'; return; }
    final imgs = await shots(3, 'Scan', burst: true); if (imgs == null) return;
    if (imgs.length < 3) { msg = 'The camera could not take all the pictures. Please try again.'; return; }
    setState(() => busyText = 'Identifying face...');
    final r = await sendMany('/api/scan', imgs, {'lat': '${pos.latitude}', 'lng': '${pos.longitude}', 'acc': '${pos.accuracy}', 'mock': '${pos.isMocked}'});
    msg = clean(r.body); good = r.statusCode == 200; retry = r.statusCode == 409;
  });

  void anotherId() => setState(() { name = null; code = null; enrolled = null; msg = ''; idCtl.clear(); });

  Widget bigButton(String text, IconData icon, VoidCallback? onTap) => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
          onPressed: busy ? null : onTap,
          icon: Icon(icon),
          label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(text, style: const TextStyle(fontSize: 17))),
          style: FilledButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));

  @override
  Widget build(BuildContext c) {
    if (!ready) {
      return const Scaffold(
          backgroundColor: navy,
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(14))), child: Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Image(image: AssetImage('assets/logo.png'), height: 64))),
            SizedBox(height: 14),
            Text('Capital Development Authority', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text('Starting...', style: TextStyle(color: Colors.white70)),
          ])));
    }
    final isOwner = code != null && code == ownerCode;
    return Scaffold(
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(24, MediaQuery.of(c).padding.top + 24, 24, 30),
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [navy, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
          child: const Column(children: [
            DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(14))), child: Padding(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Image(image: AssetImage('assets/logo.png'), height: 52))),
            SizedBox(height: 12),
            Text('Capital Development Authority', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Face Attendance System', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(children: [
                  if (name == null) ...[
                    Text(ownerCode == null ? 'First time on this phone' : 'Mark attendance for another person',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text('Enter your Employee ID', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    TextField(
                        controller: idCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Employee ID', prefixIcon: const Icon(Icons.badge_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
                    const SizedBox(height: 16),
                    bigButton('Continue', Icons.arrow_forward, () => login(idCtl.text.trim())),
                    if (ownerCode != null)
                      TextButton(onPressed: busy ? null : () => login(ownerCode!), child: const Text('Retry / back to my account')),
                  ] else ...[
                    Text('Hello, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 18),
                    if (enrolled == false) ...[
                      const Text('First login: register your face. Three photos are taken, 5 seconds apart, looking straight at the camera.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      bigButton('Register my face', Icons.face, enroll),
                    ] else
                      bigButton('Mark attendance', Icons.fingerprint, checkIn),
                    const SizedBox(height: 6),
                    if (isOwner) ...[
                      if (enrolled == true && ownerAllows) ...[
                        bigButton('Scan a face (supervisor)', Icons.groups, scanFace),
                        TextButton(onPressed: anotherId, child: const Text('Use another ID (forgot phone?)')),
                      ],
                    ] else
                      TextButton(onPressed: () => login(ownerCode!), child: const Text('Back to my account')),
                  ],
                  if (busy) Padding(padding: const EdgeInsets.only(top: 16), child: Column(children: [const CircularProgressIndicator(), const SizedBox(height: 10), Text(busyText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))])),
                  if (msg.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: good ? const Color(0xFFE3F6E8) : retry ? const Color(0xFFFFF3D6) : const Color(0xFFFDEAEA), borderRadius: BorderRadius.circular(12)),
                      child: Text(msg, textAlign: TextAlign.center, style: TextStyle(color: good ? const Color(0xFF1A7A35) : retry ? const Color(0xFF9A6A00) : const Color(0xFFB3261E), fontSize: 15)),
                    ),
                ]),
              ),
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.only(bottom: 14), child: Text('$brand - Face Attendance System', style: TextStyle(color: Colors.black45, fontSize: 12))),
      ]),
    );
  }
}

// Opens the FRONT camera once and takes 1 or 3 photos by itself, with a 5 second countdown before each.
class SelfieScreen extends StatefulWidget {
  final String title; final int shots; final bool burst;
  const SelfieScreen({super.key, this.title = 'Face scan', this.shots = 1, this.burst = false});
  @override State<SelfieScreen> createState() => _SelfieState();
}

class _SelfieState extends State<SelfieScreen> {
  CameraController? cc; String info = 'Starting camera...'; int count = 5; bool pause = false, shooting = false; Timer? timer; final List<XFile> taken = [];

  @override
  void initState() { super.initState(); start(); }

  Future<void> start() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500)); // let any previous camera release
      final cams = await availableCameras();
      final cam = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
      cc = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
      await cc!.initialize();
      if (!mounted) return;
      setState(() => info = widget.burst ? 'Look at the screen and blink naturally' : (widget.shots > 1 ? 'Photo 1 of ${widget.shots} - look straight' : 'Look straight at the camera'));
      countdown();
    } catch (e) { if (mounted) setState(() => info = 'Camera error: $e'); }
  }

  void countdown() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) { t.cancel(); return; }
      if (widget.burst) {   // three pictures while counting down
        if (shooting) return;
        if (count == 4 || count == 2 || count == 1) { shooting = true; try { taken.add(await cc!.takePicture()); } catch (_) {} shooting = false; }
        if (count > 1) { if (mounted) setState(() => count--); return; }
        t.cancel();
        if (mounted) Navigator.of(context).pop(taken);
        return;
      }
      if (count > 1) { setState(() => count--); return; }
      t.cancel();
      try {
        taken.add(await cc!.takePicture());
        if (taken.length >= widget.shots) { if (mounted) Navigator.of(context).pop(taken); return; }
        if (!mounted) return;
        final n = taken.length;
        setState(() { pause = true; info = 'Photo $n saved.\nGet ready for photo ${n + 1} of ${widget.shots}...'; });
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        setState(() { pause = false; count = 5; info = 'Photo ${n + 1} of ${widget.shots} - look straight'; });
        countdown();
      } catch (e) { if (mounted) setState(() => info = 'Capture error: $e'); }
    });
  }

  @override
  void dispose() { timer?.cancel(); cc?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: navy,
        appBar: AppBar(title: Text(widget.title), backgroundColor: navy, foregroundColor: Colors.white),
        body: Column(children: [
          Expanded(child: Center(child: (cc != null && cc!.value.isInitialized) ? CameraPreview(cc!) : const CircularProgressIndicator())),
          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(info, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
                if (cc != null && cc!.value.isInitialized && !pause) Text('$count', style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold)),
              ])),
        ]),
      );
}
