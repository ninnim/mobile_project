namespace TimeCapsule.API.DTOs.Capsule;

public class CapsuleResponseDto
{
    public Guid Id { get; set; }
    public Guid SenderId { get; set; }
    public string SenderName { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Message { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public DateTime UnlockDate { get; set; }
    public bool IsPublic { get; set; }
    public string Status { get; set; } = "Locked";
    public Guid? GameRoomId { get; set; }
    public Guid? ReceiverUserId { get; set; }
    public int PointsReward { get; set; }
    public int ProximityTolerance { get; set; }
    public List<CapsuleMediaDto> Media { get; set; } = new();
    public DateTime CreatedAt { get; set; }
}
