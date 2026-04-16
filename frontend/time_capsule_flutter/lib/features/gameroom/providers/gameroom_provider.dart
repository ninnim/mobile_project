import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gameroom_model.dart';
import '../../../core/network/dio_client.dart';

// ── Public game rooms list ────────────────────────────────────────────────────
// keepAlive: stays cached between tab switches; invalidate explicitly to refresh
final publicGameRoomsProvider =
    FutureProvider.autoDispose<List<GameRoomModel>>((ref) async {
  ref.keepAlive();
  final res = await dioClient.get('/gamerooms');
  return (res.data as List<dynamic>)
      .map((e) => GameRoomModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── My game rooms ─────────────────────────────────────────────────────────────
final myGameRoomsProvider =
    FutureProvider.autoDispose<List<GameRoomModel>>((ref) async {
  ref.keepAlive();
  final res = await dioClient.get('/gamerooms/my');
  return (res.data as List<dynamic>)
      .map((e) => GameRoomModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Game room detail (with capsules) ──────────────────────────────────────────
final gameRoomDetailProvider =
    FutureProvider.autoDispose.family<GameRoomModel, String>((ref, id) async {
  final res = await dioClient.get('/gamerooms/$id');
  return GameRoomModel.fromJson(res.data as Map<String, dynamic>);
});

// ── Leaderboard ────────────────────────────────────────────────────────────────
final leaderboardProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>(
        (ref, id) async {
  final res = await dioClient.get('/gamerooms/$id/leaderboard');
  return (res.data as List<dynamic>)
      .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Delete a game room ────────────────────────────────────────────────────────
Future<void> deleteGameRoom(String id) async {
  await dioClient.delete('/gamerooms/$id');
}
