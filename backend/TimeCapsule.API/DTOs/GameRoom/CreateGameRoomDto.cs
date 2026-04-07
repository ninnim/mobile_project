using System.ComponentModel.DataAnnotations;

namespace TimeCapsule.API.DTOs.GameRoom;

public class CreateGameRoomDto
{
    [Required, MaxLength(150)]
    public string Title { get; set; } = string.Empty;
    public bool IsPublic { get; set; } = true;
}
