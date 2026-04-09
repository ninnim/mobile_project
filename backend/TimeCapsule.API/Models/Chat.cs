using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TimeCapsule.API.Models;

[Table("Chats")]
public class Chat
{
    [Key]
    public Guid Id { get; set; }
    public Guid SenderId { get; set; }
    public Guid ReceiverId { get; set; }
    [Required]
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; } = false;
    [MaxLength(20)]
    public string MessageType { get; set; } = "Text"; // Text, Image, Voice
    [MaxLength(500)]
    public string? MediaUrl { get; set; }
    [MaxLength(20)]
    public string Status { get; set; } = "Sent"; // Sent, Delivered, Read
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("SenderId")]
    public User Sender { get; set; } = null!;
    [ForeignKey("ReceiverId")]
    public User Receiver { get; set; } = null!;

    public ICollection<ChatReaction> Reactions { get; set; } = new List<ChatReaction>();
}
