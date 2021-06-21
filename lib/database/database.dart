import 'package:hive/hive.dart';

part 'database.g.dart';

@HiveType(typeId: 1)
class StepcountModel extends HiveObject {
  @HiveField(0)
  String date;
  @HiveField(1)
  int steps;

  StepcountModel(this.date, this.steps);
}

class StepcountModelBox {
  Future<Box> box = Hive.openBox('steps');

  Future<void> open() async {
    Box b = await box;
    if (!b.isOpen) {
      box = Hive.openBox<StepcountModel>('steps');
    }
  }
}
