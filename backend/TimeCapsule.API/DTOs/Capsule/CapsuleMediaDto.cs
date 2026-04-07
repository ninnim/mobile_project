namespace TimeCapsule.API.DTOs.Capsule;

public class CapsuleMediaDto
{
    public Guid Id { get; set; }
    public string FileUrl { get; set; } = string.Empty;
    public string? FileType { get; set; }
}
