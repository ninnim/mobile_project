using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TimeCapsule.API.Services;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/friends")]
[Authorize]
public class FriendshipController : ControllerBase
{
    private readonly IFriendshipService _service;
    public FriendshipController(IFriendshipService service) { _service = service; }
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<IActionResult> GetFriends()
        => Ok(await _service.GetFriendsAsync(UserId));

    [HttpGet("requests/incoming")]
    public async Task<IActionResult> GetIncomingRequests()
        => Ok(await _service.GetIncomingRequestsAsync(UserId));

    [HttpGet("status/{userId:guid}")]
    public async Task<IActionResult> GetStatus(Guid userId)
        => Ok(new { status = await _service.GetFriendshipStatusAsync(UserId, userId) });

    [HttpPost("request/{userId:guid}")]
    public async Task<IActionResult> SendRequest(Guid userId)
    {
        try { return StatusCode(201, await _service.SendFriendRequestAsync(UserId, userId)); }
        catch (InvalidOperationException ex) { return BadRequest(new { error = ex.Message }); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [HttpPut("accept/{requesterId:guid}")]
    public async Task<IActionResult> Accept(Guid requesterId)
    {
        try { return Ok(await _service.AcceptFriendRequestAsync(UserId, requesterId)); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [HttpDelete("decline/{requesterId:guid}")]
    public async Task<IActionResult> Decline(Guid requesterId)
    {
        try { await _service.DeclineFriendRequestAsync(UserId, requesterId); return Ok(); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [HttpDelete("{userId:guid}")]
    public async Task<IActionResult> Remove(Guid userId)
    {
        try { await _service.RemoveFriendAsync(UserId, userId); return Ok(); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }
}
