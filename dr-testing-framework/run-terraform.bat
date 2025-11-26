@echo off
echo ===============================================
echo DR Testing Framework - Terraform Execution Tool
echo ===============================================
echo.

:: Set working directory to script location
pushd %~dp0

echo Converting JSON configuration to Terraform variables...
powershell -ExecutionPolicy Bypass -File .\scripts\convert_json_to_tfvars.ps1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to convert JSON to tfvars.
    exit /b 1
)

echo.
echo Initializing Terraform...
terraform init
if %ERRORLEVEL% neq 0 (
    echo Error: Terraform initialization failed.
    exit /b 1
)

echo.
echo Running Terraform plan...
terraform plan
if %ERRORLEVEL% neq 0 (
    echo Warning: Terraform plan completed with issues.
)

echo.
echo To apply the configuration, run:
echo terraform apply

:: Return to original directory
popd