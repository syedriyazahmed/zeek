class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class InsufficientStockException extends AppException {
  final String productName;
  final double requestedQuantity;
  final double availableQuantity;

  const InsufficientStockException({
    required this.productName,
    required this.requestedQuantity,
    required this.availableQuantity,
  }) : super(
          'Insufficient stock for $productName. Requested: $requestedQuantity, Available: $availableQuantity',
          code: 'INSUFFICIENT_STOCK',
        );
}

class InvalidPaymentSplitException extends AppException {
  const InvalidPaymentSplitException(super.message)
      : super(code: 'INVALID_PAYMENT_SPLIT');
}

class DuplicateSaleException extends AppException {
  const DuplicateSaleException([super.message = 'Duplicate transaction detected.'])
      : super(code: 'DUPLICATE_SALE');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'You do not have permission to perform this action.'])
      : super(code: 'UNAUTHORIZED');
}
