using System.ComponentModel.DataAnnotations;

namespace TimeCapsule.API.DTOs.Capsule;

public class CreateCapsuleDto
{
    [Required, MaxLength(150)]
    public string Title { get; set; } = string.Empty;
    [Required, MaxLength(5000)]
    public string Message { get; set; } = string.Empty;
    [Required, Range(-90, 90)]
    public double Latitude { get; set; }
    [Required, Range(-180, 180)]
    public double Longitude { get; set; }
    [Required]
    public DateTime UnlockDate { get; set; }
    public bool IsPublic { get; set; } = false;
    public Guid? GameRoomId { get; set; }
    public int PointsReward { get; set; } = 0;
    public int ProximityTolerance { get; set; } = 50;
    public Guid? ReceiverUserId { get; set; }
    public List<IFormFile>? MediaFiles { get; set; }
}
