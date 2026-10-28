import 'app_user.dart';
import 'library_entry.dart';

/// Статус дружбы между текущим пользователем и другим пользователем.
enum FriendState { none, outgoingPending, incomingPending, friends }

/// Друг вместе с книгой, которую он сейчас читает.
class FriendWithBook {
  final AppUser user;
  final LibraryEntry? currentBook;

  const FriendWithBook({required this.user, this.currentBook});
}

/// Входящий запрос в друзья.
class FriendRequest {
  final int friendshipId;
  final AppUser from;

  const FriendRequest({required this.friendshipId, required this.from});
}

/// Результат поиска пользователей.
class UserSearchResult {
  final AppUser user;
  final FriendState state;

  const UserSearchResult({required this.user, required this.state});
}
