FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/Sharee.Api/Sharee.Api.csproj src/Sharee.Api/
RUN dotnet restore src/Sharee.Api/Sharee.Api.csproj
COPY src/Sharee.Api/ src/Sharee.Api/
RUN dotnet publish src/Sharee.Api/Sharee.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "Sharee.Api.dll"]
