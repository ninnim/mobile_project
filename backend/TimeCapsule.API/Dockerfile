FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["backend/TimeCapsule.API/TimeCapsule.API.csproj", "backend/TimeCapsule.API/"]
RUN dotnet restore "backend/TimeCapsule.API/TimeCapsule.API.csproj"
COPY . .
RUN dotnet publish "backend/TimeCapsule.API/TimeCapsule.API.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
RUN mkdir -p uploads
ENTRYPOINT ["dotnet", "TimeCapsule.API.dll"]
