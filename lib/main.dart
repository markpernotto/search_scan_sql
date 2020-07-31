import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:search_scan_sql/database_helper.dart';
import 'package:flappy_search_bar/flappy_search_bar.dart';
import 'package:barcode_scan/barcode_scan.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Home(),
    );
  }
}

class Post {
  final String title;
  final String author;
  final String isbn;
  final String description;

  Post(this.title, this.author, this.isbn, this.description);
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final SearchBarController<Post> _searchBarController = SearchBarController();

  ScanResult scanResult;

  final _flashOnController = TextEditingController(text: "Flash on");
  final _flashOffController = TextEditingController(text: "Flash off");
  final _cancelController = TextEditingController(text: "Cancel");

  var _aspectTolerance = 0.00;
  // var _numberOfCameras = 0;
  var _selectedCamera = -1;
  var _useAutoFocus = true;
  var _autoEnableFlash = false;

  static final _possibleFormats = BarcodeFormat.values.toList()
    ..removeWhere((e) => e == BarcodeFormat.unknown);

  List<BarcodeFormat> selectedFormats = [..._possibleFormats];

  Future<List<Post>> _searchAllBooks(String text) async {
    List<Post> posts = [];

    var db = new DatabaseHelper();

    List rawNote = await db.searchBooks(text);
    if (rawNote != null)
      rawNote.forEach((k) => {
            posts.add(Post('${k["title"]}', '${k["author"]}', '${k["isbn"]}',
                '${k["description"]}'))
          });
    return posts;
  }

  Future<List<Post>> barcodeScan(String id) async {
    var db = new DatabaseHelper();
    return await db.booksByScan(id);
  }

  Future scan() async {
    try {
      var options = ScanOptions(
        strings: {
          "cancel": _cancelController.text,
          "flash_on": _flashOnController.text,
          "flash_off": _flashOffController.text,
        },
        restrictFormat: selectedFormats,
        useCamera: _selectedCamera,
        autoEnableFlash: _autoEnableFlash,
        android: AndroidOptions(
          aspectTolerance: _aspectTolerance,
          useAutoFocus: _useAutoFocus,
        ),
      );
      var result = await BarcodeScanner.scan(options: options);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScannedDetail(),
          settings: RouteSettings(
            arguments: result.rawContent,
          ),
        ),
      );

      setState(() => scanResult = result);
    } on PlatformException catch (e) {
      var result = ScanResult(
        type: ResultType.Error,
        format: BarcodeFormat.unknown,
      );

      if (e.code == BarcodeScanner.cameraAccessDenied) {
        setState(() {
          result.rawContent = 'The user did not grant the camera permission!';
        });
      } else {
        result.rawContent = 'Unknown error: $e';
      }
      setState(() {
        scanResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SearchBar<Post>(
          searchBarPadding: EdgeInsets.symmetric(horizontal: 10),
          headerPadding: EdgeInsets.symmetric(horizontal: 10),
          listPadding: EdgeInsets.symmetric(horizontal: 10),
          onSearch: _searchAllBooks,
          searchBarController: _searchBarController,
          scrollDirection: Axis.vertical,
          cancellationWidget: Text("Cancel"),
          emptyWidget: Text("Could Not Find the Requested Item"),
          header: Row(
            children: <Widget>[
              RaisedButton.icon(
                onPressed: scan,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10.0))),
                label: Text(
                  'Scan Books',
                  style: TextStyle(color: Colors.white),
                ),
                icon: Icon(
                  Icons.camera,
                  color: Colors.white,
                ),
                textColor: Colors.white,
                splashColor: Colors.red,
                color: Colors.black,
              ),
            ],
          ),
          onCancelled: () {
            print("Cancelled search");
          },
          mainAxisSpacing: 10,
          onItemFound: (Post post, int index) {
            return Container(
              color: Colors.lightBlue,
              child: ListTile(
                title: Text(post.title),
                isThreeLine: false,
                subtitle: Text(post.author),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchDetail(),
                      // Pass the arguments as part of the RouteSettings. The
                      // DetailScreen reads the arguments from these settings.
                      settings: RouteSettings(
                        arguments: post,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class SearchDetail extends StatelessWidget {
  Future<List> downloadData(post) async {
    var db = new DatabaseHelper();
    List rawNote = await db.getBookVersionDetail(post.title);
    if (rawNote != null && rawNote.length > 0) return rawNote;

    return post;
  }

  @override
  Widget build(BuildContext context) {
    final Post post = ModalRoute.of(context).settings.arguments;

    return FutureBuilder<List>(
      future: downloadData(post), // function where you call your api
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        else {
          List<TableRow> desc = [];

          desc.add(TableRow(children: [
            Text(post.title,
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold))
          ]));
          desc.add(TableRow(children: [
            Text(post.author,
                style: TextStyle(fontSize: 18.0, fontStyle: FontStyle.italic))
          ]));

          if (snapshot.data != null && snapshot.data.length > 0) {
            int dataCount = snapshot.data.length;
            for (int i = 0; i < dataCount; i++) {
              final currency = new NumberFormat("#,##0.00", "en_US");
              String cost = currency.format(snapshot.data[i]['cost']);
              String price = currency.format(snapshot.data[i]['price']);
              bool buy = false;

              if ((snapshot.data[i]['storeQty'] +
                      snapshot.data[i]['warehouseQty']) <
                  snapshot.data[i]['threeMonth']) buy = true;

              Color color = Colors.red;
              String decision = "PASS @ \$" + cost;

              String category = "";
              String subcategory1 = "";
              String subcategory2 = "";

              if (snapshot.data[i]['category'].length > 0) {
                category = snapshot.data[i]['category'];
              }
              if (snapshot.data[i]['subcategory1'].length > 0) {
                subcategory1 = " / ${snapshot.data[i]['subcategory1']}";
              }
              if (snapshot.data[i]['subcategory2'].length > 0) {
                subcategory2 = " / ${snapshot.data[i]['subcategory2']}";
              }

              if (buy) {
                color = Colors.blue;
                decision = "BUY @ \$" + cost;
              }

              desc.add(TableRow(children: [
                Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    // child: SingleChildScrollView(
                    //     padding: const EdgeInsets.all(18.0),
                    child: Container(
                        padding: EdgeInsets.all(4.0),
                        color: color,
                        child: new Column(children: [
                          new Container(
                              child: new Row(children: [
                            new Container(
                                width: 120.0,
                                child: Text(
                                    "${snapshot.data[i]['description']}",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold))),
                            new Container(
                                width: 160.0,
                                child: Text(decision,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.bold))),
                            new Container(
                                // width: 100.0,
                                padding: EdgeInsets.all(2.0),
                                child: Text("${snapshot.data[i]['systemSku']}",
                                    style: TextStyle(color: Colors.white)))
                          ])),
                          new Container(
                              padding: EdgeInsets.all(1.0),
                              child: new Row(children: [
                                new Container(
                                    width: 60.0,
                                    padding: EdgeInsets.all(2.0),
                                    child: new Column(
                                      children: [
                                        new Container(
                                            child: Text(
                                                "3mo: ${snapshot.data[i]['threeMonth']}",
                                                style: TextStyle(
                                                    color: Colors.white),
                                                textAlign: TextAlign.left)),
                                        new Container(
                                            child: Text(
                                                "6mo: ${snapshot.data[i]['sixMonth']}",
                                                style: TextStyle(
                                                    color: Colors.white),
                                                textAlign: TextAlign.left)),
                                        new Container(
                                            child: Text(
                                          "12mo: ${snapshot.data[i]['twelveMonth']}",
                                          style: TextStyle(color: Colors.white),
                                          textAlign: TextAlign.left,
                                        ))
                                      ],
                                    )),
                                new Container(
                                    width: 110.0,
                                    padding: EdgeInsets.all(2.0),
                                    child: new Column(
                                      children: [
                                        new Container(
                                            child: Text("Cost: \$$cost",
                                                style: TextStyle(
                                                    color: Colors.white))),
                                        new Container(
                                            child: Text("Price: \$$price",
                                                style: TextStyle(
                                                    color: Colors.white))),
                                        new Container(
                                            child: Text(
                                                "reorder Pt: ${snapshot.data[i]['reorderPoint']}",
                                                style: TextStyle(
                                                    color: Colors.white)))
                                      ],
                                    )),
                                new Container(
                                    width: 120.0,
                                    padding: EdgeInsets.all(2.0),
                                    child: new Column(
                                      children: [
                                        new Container(
                                            child: Text(
                                                "Store Qty: ${snapshot.data[i]['storeQty']}",
                                                style: TextStyle(
                                                    color: Colors.white))),
                                        new Container(
                                            child: Text(
                                                "WHS Qty: ${snapshot.data[i]['warehouseQty']}",
                                                style: TextStyle(
                                                    color: Colors.white))),
                                        new Container(
                                            child: Text(
                                                "reorder Lvl: ${snapshot.data[i]['reorderLevel']}",
                                                style: TextStyle(
                                                    color: Colors.white)))
                                      ],
                                    )),
                              ])),
                          new Container(
                              child: new Row(children: [
                            new Container(
                                child: Text(category,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold))),
                            new Container(
                                child: Text(subcategory1,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.0,
                                        fontStyle: FontStyle.italic))),
                            new Container(
                                child: Text(subcategory2,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.0,
                                        fontStyle: FontStyle.italic))),
                          ])),
                          new Container(
                              child: new Row(children: [
                            new Container(
                                width: 160.0,
                                child: Text(
                                  " updated ${snapshot.data[i]['updateTime']}",
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 14.0),
                                )),
                            new Container(
                                width: 160.0,
                                child: Text(
                                  " created ${snapshot.data[i]['createTime']}",
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 14.0),
                                ))
                          ]))
                        ]))
                    // child: Text(i["description"],
                    //     style: TextStyle(color: Colors.white)))
                    // )
                    )
              ]));
            }
          }

          return Scaffold(
              appBar: AppBar(
                title: Text(post.title),
              ),
              body: SafeArea(
                  child: Table(
                border: TableBorder.all(
                    color: Colors.black26, width: 1, style: BorderStyle.none),
                children: desc,
              )));
        }
        // }
      },
    );
  }
}

bool isNumeric(String s) {
  if (s == null) {
    return false;
  }
  return double.tryParse(s) != null;
}

class ScannedDetail extends StatelessWidget {
  Future<List> downloadData(post) async {
    var db = new DatabaseHelper();
    List rawNote = await db.booksByScan(post);
    if (rawNote != null && rawNote.length > 0) return rawNote;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String post = ModalRoute.of(context).settings.arguments;

    return FutureBuilder<List>(
      future: downloadData(post), // function where you call your api
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.waiting) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          else {
            List<TableRow> desc = [];
            if (snapshot.data != null) {
              var first = snapshot.data[0];

              desc.add(TableRow(children: [
                Text(first["title"],
                    style:
                        TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold))
              ]));
              desc.add(TableRow(children: [
                Text(first["author"],
                    style:
                        TextStyle(fontSize: 16.0, fontStyle: FontStyle.italic))
              ]));

              int dataCount = snapshot.data.length;
              for (int i = 0; i < dataCount; i++) {
                final currency = new NumberFormat("#,##0.00", "en_US");
                String cost = currency.format(snapshot.data[i]['cost']);
                String price = currency.format(snapshot.data[i]['price']);
                bool buy = false;

                if ((snapshot.data[i]['storeQty'] +
                        snapshot.data[i]['warehouseQty']) <
                    snapshot.data[i]['threeMonth']) buy = true;

                Color color = Colors.red;
                String decision = "PASS @ \$" + cost;

                String category = "";
                String subcategory1 = "";
                String subcategory2 = "";

                if (snapshot.data[i]['category'].length > 0) {
                  category = snapshot.data[i]['category'];
                }
                if (snapshot.data[i]['subcategory1'].length > 0) {
                  subcategory1 = " / ${snapshot.data[i]['subcategory1']}";
                }
                if (snapshot.data[i]['subcategory2'].length > 0) {
                  subcategory2 = " / ${snapshot.data[i]['subcategory2']}";
                }

                if (buy) {
                  color = Colors.blue;
                  decision = "BUY @ \$" + cost;
                }

                desc.add(TableRow(children: [
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      // child: SingleChildScrollView(
                      //     padding: const EdgeInsets.all(18.0),
                      child: Container(
                          padding: EdgeInsets.all(4.0),
                          color: color,
                          child: new Column(children: [
                            new Container(
                                child: new Row(children: [
                              new Container(
                                  width: 120.0,
                                  child: Text(
                                      "${snapshot.data[i]['description']}",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold))),
                              new Container(
                                  width: 160.0,
                                  child: Text(decision,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.bold))),
                              new Container(
                                  // width: 100.0,
                                  padding: EdgeInsets.all(2.0),
                                  child: Text(
                                      "${snapshot.data[i]['systemSku']}",
                                      style: TextStyle(color: Colors.white)))
                            ])),
                            new Container(
                                padding: EdgeInsets.all(1.0),
                                child: new Row(children: [
                                  new Container(
                                      width: 60.0,
                                      padding: EdgeInsets.all(2.0),
                                      child: new Column(
                                        children: [
                                          new Container(
                                              child: Text(
                                                  "3mo: ${snapshot.data[i]['threeMonth']}",
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                  textAlign: TextAlign.left)),
                                          new Container(
                                              child: Text(
                                                  "6mo: ${snapshot.data[i]['sixMonth']}",
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                  textAlign: TextAlign.left)),
                                          new Container(
                                              child: Text(
                                            "12mo: ${snapshot.data[i]['twelveMonth']}",
                                            style:
                                                TextStyle(color: Colors.white),
                                            textAlign: TextAlign.left,
                                          ))
                                        ],
                                      )),
                                  new Container(
                                      width: 110.0,
                                      padding: EdgeInsets.all(2.0),
                                      child: new Column(
                                        children: [
                                          new Container(
                                              child: Text("Cost: \$$cost",
                                                  style: TextStyle(
                                                      color: Colors.white))),
                                          new Container(
                                              child: Text("Price: \$$price",
                                                  style: TextStyle(
                                                      color: Colors.white))),
                                          new Container(
                                              child: Text(
                                                  "reorder Pt: ${snapshot.data[i]['reorderPoint']}",
                                                  style: TextStyle(
                                                      color: Colors.white)))
                                        ],
                                      )),
                                  new Container(
                                      width: 120.0,
                                      padding: EdgeInsets.all(2.0),
                                      child: new Column(
                                        children: [
                                          new Container(
                                              child: Text(
                                                  "Store Qty: ${snapshot.data[i]['storeQty']}",
                                                  style: TextStyle(
                                                      color: Colors.white))),
                                          new Container(
                                              child: Text(
                                                  "WHS Qty: ${snapshot.data[i]['warehouseQty']}",
                                                  style: TextStyle(
                                                      color: Colors.white))),
                                          new Container(
                                              child: Text(
                                                  "reorder Lvl: ${snapshot.data[i]['reorderLevel']}",
                                                  style: TextStyle(
                                                      color: Colors.white)))
                                        ],
                                      )),
                                ])),
                            new Container(
                                child: new Row(children: [
                              new Container(
                                  child: Text(category,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold))),
                              new Container(
                                  child: Text(subcategory1,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          fontStyle: FontStyle.italic))),
                              new Container(
                                  child: Text(subcategory2,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          fontStyle: FontStyle.italic))),
                            ])),
                            new Container(
                                child: new Row(children: [
                              new Container(
                                  width: 160.0,
                                  child: Text(
                                    " updated ${snapshot.data[i]['updateTime']}",
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 14.0),
                                  )),
                              new Container(
                                  width: 160.0,
                                  child: Text(
                                    " created ${snapshot.data[i]['createTime']}",
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 14.0),
                                  ))
                            ]))
                          ]))
                      // child: Text(i["description"],
                      //     style: TextStyle(color: Colors.white)))
                      // )
                      )
                ]));
              }

              return Scaffold(
                  appBar: AppBar(
                    title: Text(first["title"]),
                  ),
                  body: SafeArea(
                      child: Table(
                    border: TableBorder.all(
                        color: Colors.black26,
                        width: 1,
                        style: BorderStyle.none),
                    children: desc,
                  )));
            } else {
              desc.add(TableRow(children: [
                Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                        padding: EdgeInsets.all(10.0),
                        child: Text("No Books Found with ISBN $post")))
              ]));

              return Scaffold(
                  appBar: AppBar(
                    title: Text("Title Not Found"),
                  ),
                  body: SafeArea(
                      child: Table(
                    border: TableBorder.all(
                        color: Colors.black26,
                        width: 1,
                        style: BorderStyle.none),
                    children: desc,
                  )));
            }
          }
        } else {
          return Container();
        }
      },
    );
  }
}
