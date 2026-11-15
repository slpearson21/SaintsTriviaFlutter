import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saints Trivia',
      darkTheme: ThemeData.dark(),
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blueGrey,
      ),
      home: const MyHomePage(title: 'Saints Trivia'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool otCheckState = false;
  bool ntCheckState = false;
  bool bomCheckState = false;
  bool dcCheckState = false;
  bool pgpCheckState = false;

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SizedBox.expand(
        child: Container(
          padding: const EdgeInsets.only(top: 25.0, left: 15.0, right: 15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Pick Your Trivia',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              CheckboxListTile(
                value: otCheckState,
                onChanged: (bool? value) {
                  setState(() {
                    otCheckState = value!;
                  });
                },
                title: const Text("Old Testament"),
              ),
              const Divider(height: 10.0),
              CheckboxListTile(
                value: ntCheckState,
                onChanged: (bool? value) {
                  setState(() {
                    ntCheckState = value!;
                  });
                },
                title: const Text("New Testament"),
              ),
              const Divider(height: 10.0),
              CheckboxListTile(
                value: bomCheckState,
                onChanged: (bool? value) {
                  setState(() {
                    bomCheckState = value!;
                  });
                },
                title: const Text("Book of Mormon"),
              ),
              const Divider(height: 10.0),
              CheckboxListTile(
                value: dcCheckState,
                onChanged: (bool? value) {
                  setState(() {
                    dcCheckState = value!;
                  });
                },
                title: const Text("Doctrine and Covenants"),
              ),
              const Divider(height: 10.0),
              CheckboxListTile(
                value: pgpCheckState,
                onChanged: (bool? value) {
                  setState(() {
                    pgpCheckState = value!;
                  });
                },
                title: const Text("Pearl of Great Price"),
              ),
              const Divider(height: 20.0),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
                child: const Text("GO!", style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
