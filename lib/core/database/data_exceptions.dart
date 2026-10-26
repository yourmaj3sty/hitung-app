/// Kesalahan validasi data yang pesannya aman ditampilkan langsung ke pengguna.
class DataValidationException implements Exception {
  final String message;

  const DataValidationException(this.message);

  @override
  String toString() => message;
}
