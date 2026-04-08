using System.ComponentModel.DataAnnotations;

namespace TimeCapsule.API.DTOs.Post;

public class CreatePostDto
{
    [Required]
    public string Content { get; set; } = string.Empty;
    public IFormFile? MediaFile { get; set; }
    /// Comma-separated list of user GUIDs to tag
    public string? TaggedUserIds { get; set; }
}
