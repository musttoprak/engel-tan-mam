import 'dart:math';

import 'package:engeltanimam/constants/app_colors.dart';
import 'package:engeltanimam/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isOnay = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String onayText = '';
  String lastStatus = '';
  String _currentLocaleId = '';
  final SpeechToText speech = SpeechToText();
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    requestMicrophonePermission();
  }

  Future<void> requestMicrophonePermission() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      // Mikrofon erişim izni verildi, konuşma tanıma işlemini başlatın
      await initSpeechState();
      await _speak(
          "Merhaba, lütfen gideceğiniz yeri söyleyin ve ardından komutları takip edin");
      startListening();
      //stopListening();
      //cancelListening();
    } else if (status.isDenied) {
      // Kullanıcı izni reddetti, uygun bir şekilde yanıt verin
    } else if (status.isPermanentlyDenied) {
      // Kullanıcı izni kalıcı olarak reddetti, ayarlara yönlendirin
      openAppSettings();
    }
  }

  // _HomeScreenState sınıfınızın dışına, resultListener fonksiyonunun altına
  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("tr_TR"); // Tanınan dil
    await flutterTts.speak(text);
    await flutterTts
        .awaitSpeakCompletion(true); // Seslendirme tamamlanana kadar bekleyin
  }

  Future<void> initSpeechState() async {
    var hasSpeech = await speech.initialize(
        onStatus: statusListener,
        debugLogging: true,
        finalTimeout: const Duration(milliseconds: 0));
    if (hasSpeech) {

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale?.localeId ?? '';
    }

    if (!mounted) return;

    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Anasayfa"),
          backgroundColor: AppColors.headerTextColor,
          actions: [
            IconButton(
                onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapsScreen(routeText: onayText),
                      ),
                    ),
                icon: const Icon(Icons.add))
          ]),
      body: Column(children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                color: AppColors.primaryWhiteColor,
                child: Center(
                  child: Text(
                    lastWords,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Positioned.fill(
                bottom: 100,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: InkWell(
                    onTap: () => startListening(),
                    child: Container(
                      width: MediaQuery.sizeOf(context).width * .6,
                      height: MediaQuery.sizeOf(context).width * .6,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                              blurRadius: .26,
                              spreadRadius: level * 1.5,
                              color: Colors.black.withOpacity(.05))
                        ],
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(62),
                      ),
                      child: Icon(
                        Icons.mic,
                        size: MediaQuery.sizeOf(context).width * .1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: AppColors.primaryWhiteColor,
          child: Center(
            child: speech.isListening
                ? const Text(
                    "Dinliyorum.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                : const Text(
                    'Dinlemiyorum',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ]),
    );
  }

  Future<void> startListening() async {
    print("tıklandı");
    lastWords = '';
    await speech.listen(
      onResult: resultListener,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      localeId: _currentLocaleId,
      onSoundLevelChange: soundLevelListener,
    );
    setState(() {});
  }

  void stopListening() {
    speech.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  Future<void> resultListener(SpeechRecognitionResult result) async {
    setState(() {
      print("result' a geldik");
      lastWords = '${result.recognizedWords} - ${result.finalResult}';
    });
    if (result.finalResult) {
      if (isOnay &&
          result.recognizedWords.toUpperCase() == "Onaylıyorum".toUpperCase() &&
          onayText != '') {
        setState(() {});
        isOnay = false;
        await Future.delayed(const Duration(seconds: 1));
        await _speak(
                "İşleminiz gerçekleştirildi şimdi rotanız oluşturuluyor lütfen bekleyiniz.")
            .then(
          (value) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapsScreen(routeText: onayText),
            ),
          ),
        );
      } else {
        setState(() {});
        isOnay = true;
        onayText = result.recognizedWords;
        await Future.delayed(const Duration(seconds: 1));
        await _speak(
            "${result.recognizedWords} mu demek isteediniz eğer doğru ise onaylıyorum  diyiniz değil ise başka bir şey deyiniz");
        await startListening();
        return;
      }
      print("bitti");
    } else {
      print("daha ses aktf");
    }
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    // _logEvent('sound level $level: $minSoundLevel - $maxSoundLevel ');
    setState(() {
      this.level = level;
      print("sound level dinleniyor $level");
    });
  }

  void statusListener(String status) {
    setState(() {
      lastStatus = status;
    });
  }
}
