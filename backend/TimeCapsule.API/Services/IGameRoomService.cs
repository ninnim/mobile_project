using TimeCapsule.API.DTOs.GameRoom;

namespace TimeCapsule.API.Services;

public interface IGameRoomService
{
    Task<GameRoomResponseDto> CreateAsync(Guid creatorId, CreateGameRoomDto dto);
    Task<List<GameRoomResponseDto>> GetPublicAsync();
    Task<GameRoomResponseDto> GetByIdAsync(Guid id);
    Task<List<GameRoomResponseDto>> GetMyAsync(Guid userId);
}
