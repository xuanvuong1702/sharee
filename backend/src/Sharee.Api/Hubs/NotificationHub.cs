using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Hubs;

[Authorize]
public sealed class NotificationHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId = Context.User!.GetUserId();
        await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
        await base.OnConnectedAsync();
    }
}
