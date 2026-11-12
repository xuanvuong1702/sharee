import 'package:flutter_test/flutter_test.dart';
import 'package:sharee_mobile/core/format.dart';

void main() {
  test('money formats VND with dots', () {
    expect(money(180000), '180.000đ');
    expect(money(0), '0đ');
  });

  test('status labels are human readable', () {
    expect(statusLabel('confirmed'), 'Đã xác nhận');
    expect(statusLabel('pending_payment'), 'Chờ thanh toán');
  });
}
