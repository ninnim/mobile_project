using TimeCapsule.API.DTOs.Capsule;

namespace TimeCapsule.API.DTOs.GameRoom;

public class GameRoomResponseDto
{
    public Guid Id { get; set; }
    public Guid CreatorId { get; set; }
    public string CreatorName { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public bool IsPublic { get; set; }
    public int CapsuleCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public List<CapsuleResponseDto>? Capsules { get; set; }
}
