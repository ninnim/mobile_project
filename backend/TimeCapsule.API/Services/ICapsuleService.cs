using TimeCapsule.API.DTOs.Capsule;

namespace TimeCapsule.API.Services;

public interface ICapsuleService
{
    Task<CapsuleResponseDto> CreateAsync(Guid senderId, CreateCapsuleDto dto);
    Task<List<CapsuleResponseDto>> GetMyCapsulesAsync(Guid userId);
    Task<List<CapsuleResponseDto>> GetPublicCapsulesAsync();
    Task<CapsuleResponseDto> GetByIdAsync(Guid id, Guid requestingUserId);
    Task<UnlockResultDto> UnlockAsync(Guid capsuleId, Guid userId, UnlockCapsuleDto dto);
    Task<List<CapsuleResponseDto>> GetByGameRoomAsync(Guid gameRoomId);
}
