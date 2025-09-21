<#
.SYNOPSIS
    Script para instalação automática de aplicativos de desenvolvimento
.DESCRIPTION
    Este script instala automaticamente uma lista de aplicativos essenciais para desenvolvimento
    usando o Windows Package Manager (winget) como gerenciador principal.
    Se o aplicativo já estiver instalado, verifica e executa atualizações disponíveis.
.PARAMETER AppList
    Lista de aplicativos a serem instalados (opcional - usa lista padrão se não especificado)
.PARAMETER SkipDependencies
    Pula a verificação e instalação de dependências
.PARAMETER SkipUpdates
    Pula as atualizações de aplicativos já instalados
.EXAMPLE
    .\Install-DevApps.ps1
    .\Install-DevApps.ps1 -AppList @("Git.Git", "Docker.DockerDesktop")
    .\Install-DevApps.ps1 -SkipUpdates
.NOTES
    Autor: PowerShell Expert
    Versão: 2.0
    Requer: Windows 10/11, PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$AppList = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDependencies,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipUpdates
)

# Configuração de aplicativos padrão
$DefaultApps = @{
    "Docker Desktop"              = "Docker.DockerDesktop"
    "Postman"                    = "Postman.Postman"
    "Visual Studio Community"    = "Microsoft.VisualStudio.2022.Community"
    "Git"                       = "Git.Git"
    "Slack"                     = "SlackTechnologies.Slack"
    "DBeaver"                   = "dbeaver.dbeaver"
    "SQL Server Management Studio" = "Microsoft.SQLServerManagementStudio"
}

# Enum para status de instalação
enum InstallStatus {
    Success
    Failed
    Updated
    AlreadyLatest
    Skipped
}

# Função para verificar se o script está sendo executado como administrador
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Função para verificar se o winget está instalado
function Test-WingetInstalled {
    try {
        $wingetVersion = winget --version
        Write-Host "✓ Windows Package Manager encontrado: $wingetVersion" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Windows Package Manager (winget) não encontrado"
        return $false
    }
}

# Função para instalar o winget se necessário
function Install-Winget {
    Write-Host "🔄 Instalando Windows Package Manager..." -ForegroundColor Yellow
    
    try {
        # Baixar e instalar App Installer do Microsoft Store
        $appInstallerUrl = "https://aka.ms/getwinget"
        Start-Process $appInstallerUrl
        
        Write-Host "⚠️  Por favor, instale o 'Instalador de Aplicativos' da Microsoft Store que foi aberto." -ForegroundColor Yellow
        Write-Host "⚠️  Após a instalação, execute este script novamente." -ForegroundColor Yellow
        
        Read-Host "Pressione Enter após completar a instalação para continuar"
        
        # Verificar novamente
        if (-not (Test-WingetInstalled)) {
            throw "Winget ainda não está disponível após a instalação"
        }
    }
    catch {
        Write-Error "Erro ao instalar o Windows Package Manager: $($_.Exception.Message)"
        return $false
    }
    
    return $true
}

# Função para verificar e instalar dependências
function Install-Dependencies {
    Write-Host "`n🔍 Verificando dependências..." -ForegroundColor Cyan
    
    # Verificar winget
    if (-not (Test-WingetInstalled)) {
        if (-not (Install-Winget)) {
            throw "Não foi possível instalar o Windows Package Manager"
        }
    }
    
    # Atualizar winget sources
    Write-Host "🔄 Atualizando fontes do winget..." -ForegroundColor Yellow
    try {
        winget source update
        Write-Host "✓ Fontes atualizadas com sucesso" -ForegroundColor Green
    }
    catch {
        Write-Warning "Aviso: Não foi possível atualizar as fontes do winget"
    }
}

# Função para verificar se um aplicativo está instalado
function Test-ApplicationInstalled {
    param(
        [string]$PackageId
    )
    
    try {
        $result = winget list --id $PackageId --exact 2>$null
        return ($LASTEXITCODE -eq 0 -and $result -match $PackageId)
    }
    catch {
        return $false
    }
}

# Função para verificar se há atualizações disponíveis
function Test-UpdateAvailable {
    param(
        [string]$PackageId
    )
    
    try {
        $result = winget upgrade --id $PackageId --include-unknown 2>$null
        return ($LASTEXITCODE -eq 0 -and $result -match $PackageId)
    }
    catch {
        return $false
    }
}

# Função para atualizar um aplicativo
function Update-Application {
    param(
        [string]$AppName,
        [string]$PackageId
    )
    
    Write-Host "🔄 Atualizando $AppName..." -ForegroundColor Yellow
    
    try {
        $updateResult = winget upgrade --id $PackageId --accept-package-agreements --accept-source-agreements --silent
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $AppName atualizado com sucesso" -ForegroundColor Green
            return [InstallStatus]::Updated
        }
        else {
            Write-Warning "⚠️  Possível problema na atualização de $AppName (Código: $LASTEXITCODE)"
            return [InstallStatus]::Failed
        }
    }
    catch {
        Write-Error "❌ Erro ao atualizar ${AppName}: $($_.Exception.Message)"
        return [InstallStatus]::Failed
    }
}

# Função para instalar um aplicativo
function Install-NewApplication {
    param(
        [string]$AppName,
        [string]$PackageId
    )
    
    Write-Host "🚀 Instalando $AppName..." -ForegroundColor Cyan
    
    try {
        $installResult = winget install --id $PackageId --accept-package-agreements --accept-source-agreements --silent
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ $AppName instalado com sucesso" -ForegroundColor Green
            return [InstallStatus]::Success
        }
        else {
            Write-Warning "⚠️  Possível problema na instalação de $AppName (Código: $LASTEXITCODE)"
            return [InstallStatus]::Failed
        }
    }
    catch {
        Write-Error "❌ Erro ao instalar ${AppName}: $($_.Exception.Message)"
        return [InstallStatus]::Failed
    }
}

# Função principal para processar um aplicativo
function Install-Application {
    param(
        [string]$AppName,
        [string]$PackageId
    )
    
    Write-Host "`n📦 Processando $AppName..." -ForegroundColor Cyan
    
    try {
        # Verificar se o aplicativo está instalado
        if (Test-ApplicationInstalled -PackageId $PackageId) {
            Write-Host "ℹ️  $AppName já está instalado" -ForegroundColor Blue
            
            if ($SkipUpdates) {
                Write-Host "⏭️  Pulando verificação de atualizações (SkipUpdates ativado)" -ForegroundColor Yellow
                return [InstallStatus]::Skipped
            }
            
            # Verificar se há atualizações disponíveis
            Write-Host "🔍 Verificando atualizações para $AppName..." -ForegroundColor Yellow
            
            if (Test-UpdateAvailable -PackageId $PackageId) {
                Write-Host "📥 Atualização disponível para $AppName" -ForegroundColor Cyan
                return Update-Application -AppName $AppName -PackageId $PackageId
            }
            else {
                Write-Host "✅ $AppName já está na versão mais recente" -ForegroundColor Green
                return [InstallStatus]::AlreadyLatest
            }
        }
        else {
            # Aplicativo não está instalado - fazer instalação
            return Install-NewApplication -AppName $AppName -PackageId $PackageId
        }
    }
    catch {
        Write-Error "❌ Erro ao processar ${AppName}: $($_.Exception.Message)"
        return [InstallStatus]::Failed
    }
}

# Função para criar relatório de instalação
function New-InstallationReport {
    param(
        [hashtable]$Results
    )
    
    Write-Host "`n📊 RELATÓRIO DE INSTALAÇÃO E ATUALIZAÇÕES" -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor Magenta
    
    $counters = @{
        Success = 0
        Failed = 0
        Updated = 0
        AlreadyLatest = 0
        Skipped = 0
    }
    
    foreach ($app in $Results.Keys) {
        $status = $Results[$app]
        $counters[$status.ToString()]++
        
        switch ($status) {
            ([InstallStatus]::Success) { 
                Write-Host "✅ $app - INSTALADO" -ForegroundColor Green 
            }
            ([InstallStatus]::Updated) { 
                Write-Host "🔄 $app - ATUALIZADO" -ForegroundColor Cyan 
            }
            ([InstallStatus]::AlreadyLatest) { 
                Write-Host "✅ $app - JÁ ATUALIZADO" -ForegroundColor Green 
            }
            ([InstallStatus]::Failed) { 
                Write-Host "❌ $app - FALHA" -ForegroundColor Red 
            }
            ([InstallStatus]::Skipped) { 
                Write-Host "⏭️  $app - PULADO" -ForegroundColor Yellow 
            }
        }
    }
    
    Write-Host "`n📈 RESUMO DETALHADO:" -ForegroundColor Cyan
    Write-Host "   Instalações: $($counters.Success)" -ForegroundColor Green
    Write-Host "   Atualizações: $($counters.Updated)" -ForegroundColor Cyan
    Write-Host "   Já atualizados: $($counters.AlreadyLatest)" -ForegroundColor Green
    Write-Host "   Pulados: $($counters.Skipped)" -ForegroundColor Yellow
    Write-Host "   Falhas: $($counters.Failed)" -ForegroundColor Red
    Write-Host "   Total processado: $($Results.Count)" -ForegroundColor White
    
    # Calcular taxa de sucesso
    $successfulOperations = $counters.Success + $counters.Updated + $counters.AlreadyLatest
    $successRate = [math]::Round(($successfulOperations / $Results.Count) * 100, 1)
    Write-Host "   Taxa de sucesso: $successRate%" -ForegroundColor $(if($successRate -ge 90) { "Green" } elseif($successRate -ge 70) { "Yellow" } else { "Red" })
}

# Função principal
function Start-Installation {
    Write-Host "🎯 INSTALADOR E ATUALIZADOR AUTOMÁTICO DE APLICATIVOS" -ForegroundColor Magenta
    Write-Host "=" * 65 -ForegroundColor Magenta
    
    # Verificar privilégios de administrador
    if (-not (Test-Administrator)) {
        Write-Warning "⚠️  Este script deve ser executado como Administrador para melhor compatibilidade"
        $continue = Read-Host "Deseja continuar mesmo assim? (s/N)"
        if ($continue -notmatch '^[Ss]$') {
            Write-Host "Execução cancelada pelo usuário" -ForegroundColor Yellow
            return
        }
    }
    
    # Instalar dependências se necessário
    if (-not $SkipDependencies) {
        Install-Dependencies
    }
    
    # Determinar lista de aplicativos
    $appsToInstall = if ($AppList.Count -gt 0) {
        $customApps = @{}
        foreach ($app in $AppList) {
            $appName = ($DefaultApps.GetEnumerator() | Where-Object { $_.Value -eq $app }).Key
            if ($appName) {
                $customApps[$appName] = $app
            }
            else {
                $customApps[$app] = $app
            }
        }
        $customApps
    }
    else {
        $DefaultApps
    }
    
    Write-Host "`n📋 Aplicativos a serem processados:" -ForegroundColor Cyan
    $appsToInstall.Keys | ForEach-Object { Write-Host "   • $_" -ForegroundColor White }
    
    if ($SkipUpdates) {
        Write-Host "`n⚠️  Modo SkipUpdates ativado - aplicativos já instalados não serão atualizados" -ForegroundColor Yellow
    }
    else {
        Write-Host "`n🔄 Aplicativos já instalados serão verificados para atualizações" -ForegroundColor Green
    }
    
    $confirm = Read-Host "`nDeseja continuar? (S/n)"
    if ($confirm -match '^[Nn]$') {
        Write-Host "Operação cancelada pelo usuário" -ForegroundColor Yellow
        return
    }
    
    # Processar aplicativos
    $installResults = @{}
    $totalApps = $appsToInstall.Count
    $currentApp = 0
    
    foreach ($app in $appsToInstall.GetEnumerator()) {
        $currentApp++
        Write-Host "`n[$currentApp/$totalApps]" -ForegroundColor Gray -NoNewline
        $installResults[$app.Key] = Install-Application -AppName $app.Key -PackageId $app.Value
        
        # Pausa entre processamentos para evitar sobrecarregar o sistema
        if ($currentApp -lt $totalApps) {
            Start-Sleep -Seconds 2
        }
    }
    
    # Gerar relatório
    New-InstallationReport -Results $installResults
    
    # Configurações pós-instalação
    Write-Host "`n🔧 CONFIGURAÇÕES PÓS-INSTALAÇÃO" -ForegroundColor Magenta
    Write-Host "Algumas configurações podem ser necessárias:" -ForegroundColor Yellow
    Write-Host "• Docker Desktop: Pode requerer reinicialização e configuração do WSL2" -ForegroundColor White
    Write-Host "• Visual Studio: Pode requerer configuração de workloads adicionais" -ForegroundColor White
    Write-Host "• Git: Configure seu nome e email:" -ForegroundColor White
    Write-Host "  git config --global user.name 'Seu Nome'" -ForegroundColor Gray
    Write-Host "  git config --global user.email 'seu.email@exemplo.com'" -ForegroundColor Gray
    
    Write-Host "`n🎉 Processamento concluído!" -ForegroundColor Green
}

# Tratamento de erros global
try {
    Start-Installation
}
catch {
    Write-Error "❌ Erro fatal durante a execução: $($_.Exception.Message)"
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
finally {
    Write-Host "`nPressione Enter para fechar..." -ForegroundColor Gray
    Read-Host
}