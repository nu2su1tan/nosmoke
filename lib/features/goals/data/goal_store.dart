import '../../../core/storage/json_list_store.dart';
import '../domain/savings_goal.dart';

/// Цель одна, но храним как список из одного элемента, чтобы не плодить
/// ещё один тип хранилища.
JsonListStore<SavingsGoal> goalStore() => JsonListStore<SavingsGoal>(
  key: 'goal_v1',
  fromJson: SavingsGoal.fromJson,
  toJson: (g) => g.toJson(),
);
