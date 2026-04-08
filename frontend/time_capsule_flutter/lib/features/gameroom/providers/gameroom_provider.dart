import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gameroom_model.dart';
import '../../../core/network/dio_client.dart';

// ── Public game rooms list ────────────────────────────────────────────────────
final publicGameRoomsProvider = FutureProvider.autoDispose<List<GameRoomModel>>((ref) async {
  final res = await dioClient.get('/gamerooms');
  return (res.data as List<dynamic>)
      .map((e) => GameRoomModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── My game rooms ─────────────────────────────────────────────────────────────
final myGameRoomsProvider = FutureProvider.autoDispose<List<GameRoomModel>>((ref) async {
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
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>((ref, id) async {
  final res = await dioClient.get('/gamerooms/$id/leaderboard');
  return (res.data as List<dynamic>)
      .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});
