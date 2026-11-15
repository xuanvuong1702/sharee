import 'package:intl/intl.dart';

String money(int value) => '${NumberFormat.decimalPattern('vi').format(value)}đ';

String vnd(int value) => money(value);

String hhmm(DateTime value) => DateFormat('HH:mm').format(value.toLocal());

String dayLabel(DateTime value) =>
    DateFormat('EEE, dd/MM', 'vi').format(value.toLocal());

String shortDate(DateTime value) => DateFormat('dd/MM').format(value.toLocal());

String statusLabel(String status) {
  switch (status) {
    case 'pending_driver':
      return 'Chờ tài xế duyệt';
    case 'pending_payment':
      return 'Chờ thanh toán';
    case 'confirmed':
      return 'Đã xác nhận';
    case 'completed':
      return 'Đã hoàn thành';
    case 'cancelled_by_passenger':
    case 'cancelled_by_driver':
      return 'Đã huỷ';
    case 'rejected':
      return 'Bị từ chối';
    case 'expired':
      return 'Hết hạn';
    case 'refunded':
      return 'Đã hoàn tiền';
    default:
      return status;
  }
}
