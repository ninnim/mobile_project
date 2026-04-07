namespace TimeCapsule.API.DTOs.Capsule;

public class UnlockResultDto
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public CapsuleResponseDto? Capsule { get; set; }
    public int? PointsAwarded { get; set; }
    public double? DistanceMeters { get; set; }
}
