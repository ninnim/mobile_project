using System.ComponentModel.DataAnnotations;

namespace TimeCapsule.API.DTOs.Chat;

public class SendMessageDto
{
    [Required]
    public Guid ReceiverId { get; set; }
    [Required]
    public string Message { get; set; } = string.Empty;
    public string MessageType { get; set; } = "Text";
    public IFormFile? MediaFile { get; set; }
}
