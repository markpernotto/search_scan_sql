import 'dart:async';
import 'package:path/path.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = new DatabaseHelper.internal();

  factory DatabaseHelper() => _instance;

  final String tableName = 'inventory';
  final String itemID = 'itemID';
  final String title = 'title';
  final String author = 'author';
  final String isbnList = 'isbnList';
  final String systemSku = 'systemSku';
  final String description = 'description';
  final String threeMonth = 'threeMonth';
  final String sixMonth = 'sixMonth';
  final String twelveMonth = 'twelveMonth';
  final String price = 'price';
  final String cost = 'cost';
  final String storeQty = 'storeQty';
  final String warehouseQty = 'warehouseQty';
  final String category = 'category';
  final String subcategory1 = 'subcategory1';
  final String subcategory2 = 'subcategory2';
  final String createTime = 'createTime';
  final String updateTime = 'updateTime';
  final String reorderPoint = 'reorderPoint';
  final String reorderLevel = 'reorderLevel';

  static Database _db;

  DatabaseHelper.internal();

  Future<Database> get db async {
    if (_db != null) {
      return _db;
    }
    _db = await initDb();

    return _db;
  }

  initDb() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'local.db');

    var exists = await databaseExists(path);

    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      ByteData data = await rootBundle.load(join("assets", "preloaded.db"));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      await File(path).writeAsBytes(bytes, flush: true);
    }

    var db = await openDatabase(path, readOnly: true);
    return db;
  }

  Future<List> searchBooks(text) async {
    var dbClient = await db;

    if (isNumeric(text) && text.length == 13) {
      List<Map> result = await dbClient.query(tableName,
          columns: [
            title,
            author,
          ],
          where: '$isbnList LIKE ?',
          whereArgs: ["%$text%"],
          groupBy: "$title");
      if (result.length > 0) {
        return result;
      }
    } else {
      List<Map> result = await dbClient.query(tableName,
          columns: [
            title,
            author,
          ],
          where: '$title LIKE ? OR $author LIKE ?',
          whereArgs: ["%$text%", "%$text%"],
          groupBy: "$title");
      if (result.length > 0) {
        return result;
      }
    }

    return null;
  }

  Future<List> getBookVersionDetail(text) async {
    var dbClient = await db;

    List<Map> result = await dbClient.query(tableName,
        columns: [
          description,
          threeMonth,
          sixMonth,
          twelveMonth,
          systemSku,
          price,
          cost,
          category,
          subcategory1,
          subcategory2,
          storeQty,
          warehouseQty,
          createTime,
          updateTime,
          reorderPoint,
          reorderLevel
        ],
        where: '$title = ?',
        whereArgs: ["$text"]);

    if (result.length > 0) {
      return result;
    }

    return null;
  }

  Future<List> booksByScan(id) async {
    if (id.length == 13) {
      var dbClient = await db;

      List<Map> result = await dbClient.query(
        tableName,
        columns: [
          author,
          title,
          description,
          threeMonth,
          sixMonth,
          twelveMonth,
          systemSku,
          price,
          cost,
          category,
          subcategory1,
          subcategory2,
          storeQty,
          warehouseQty,
          createTime,
          updateTime,
          reorderPoint,
          reorderLevel
        ],
        where: '$isbnList LIKE ?',
        whereArgs: ["%$id%"],
      );

      if (result.length > 0) {
        return result;
      }
    }

    return null;
  }

  Future close() async {
    var dbClient = await db;
    return dbClient.close();
  }

  bool isNumeric(String s) {
    if (s == null) {
      return false;
    }
    return double.tryParse(s) != null;
  }
}
