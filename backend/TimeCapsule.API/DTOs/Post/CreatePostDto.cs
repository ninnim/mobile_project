using System.ComponentModel.DataAnnotations;

namespace TimeCapsule.API.DTOs.Post;

public class CreatePostDto
{
    [Required]
    public string Content { get; set; } = string.Empty;
    public IFormFile? MediaFile { get; set; }
}
