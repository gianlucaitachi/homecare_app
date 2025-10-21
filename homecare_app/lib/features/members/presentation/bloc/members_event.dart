import 'package:equatable/equatable.dart';

abstract class MembersEvent extends Equatable {
  const MembersEvent();

  @override
  List<Object?> get props => [];
}

class MembersRequested extends MembersEvent {
  const MembersRequested({this.familyId, this.silent = false});

  final String? familyId;
  final bool silent;

  @override
  List<Object?> get props => [familyId, silent];
}

class MembersRefreshed extends MembersEvent {
  const MembersRefreshed();
}
