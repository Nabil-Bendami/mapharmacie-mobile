import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../organizations/providers/organization_providers.dart';
import '../domain/sale.dart';

class CartNotifier extends Notifier<List<SaleLine>> {
  @override
  List<SaleLine> build() {
    ref.watch(currentOrganizationProvider);
    return const [];
  }

  void add(SaleLine line) {
    final index = state.indexWhere((item) => item.productId == line.productId);
    if (index < 0) {
      state = List.unmodifiable([...state, line]);
    } else {
      state = List.unmodifiable([
        for (var i = 0; i < state.length; i++)
          if (i == index)
            line.withQuantity(state[i].quantity + line.quantity)
          else
            state[i],
      ]);
    }
  }

  void setQuantity(String id, int quantity) {
    state = List.unmodifiable([
      for (final item in state)
        if (item.productId != id)
          item
        else if (quantity > 0)
          item.withQuantity(quantity),
    ]);
  }

  void clear() => state = const [];
}

final cartProvider = NotifierProvider<CartNotifier, List<SaleLine>>(
  CartNotifier.new,
);
