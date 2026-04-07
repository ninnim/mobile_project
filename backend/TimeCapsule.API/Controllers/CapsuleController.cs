using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TimeCapsule.API.DTOs.Capsule;
using TimeCapsule.API.Services;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/capsules")]
[Authorize]
public class CapsuleController : ControllerBase
{
    private readonly ICapsuleService _capsules;
    public CapsuleController(ICapsuleService capsules) { _capsules = capsules; }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpPost]
    public async Task<IActionResult> Create([FromForm] CreateCapsuleDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        if (!new[] { 5, 50 }.Contains(dto.ProximityTolerance))
            return BadRequest(new { error = "ProximityTolerance must be 5 or 50." });
        try { return StatusCode(201, await _capsules.CreateAsync(UserId, dto)); }
        catch (Exception ex) { return BadRequest(new { error = ex.Message }); }
    }

    [HttpGet]
    public async Task<IActionResult> GetMy() => Ok(await _capsules.GetMyCapsulesAsync(UserId));

    [HttpGet("public")]
    public async Task<IActionResult> GetPublic() => Ok(await _capsules.GetPublicCapsulesAsync());

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        try { return Ok(await _capsules.GetByIdAsync(id, UserId)); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [HttpPost("{id:guid}/unlock")]
    public async Task<IActionResult> Unlock(Guid id, [FromBody] UnlockCapsuleDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid coordinates." });
        try { return Ok(await _capsules.UnlockAsync(id, UserId, dto)); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [HttpGet("gameroom/{gameRoomId:guid}")]
    public async Task<IActionResult> GetByGameRoom(Guid gameRoomId)
        => Ok(await _capsules.GetByGameRoomAsync(gameRoomId));
}
