# PowerShell script to convert JSON configuration to Terraform variables
# This script reads JSON configuration files and generates a terraform.tfvars file

# Configuration paths
$testEnvJsonPath = "../config/test-environments.json"
$awsRegionsJsonPath = "../config/aws-regions.json"

# Output file path
$tfvarsPath = "../terraform.tfvars"

# Function to convert JSON content to HCL format for tfvars
function ConvertTo-TfVars {
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$JsonContent,
        [Parameter(Mandatory=$true)]
        [string]$RootKey
    )

    $output = ""

    if ($RootKey -eq "environments") {
        # Handle environment-specific configuration
        $primary = $JsonContent.environments.primary
        $dr = $JsonContent.environments.dr

        $output += "project_name = `"aws-cicd-project`"`n"
        $output += "primary_region = `"$($primary.region)`"`n"
        $output += "dr_region = `"$($dr.region)`"`n"
        
        # VPC and subnet configuration
        $output += "vpc_cidr_primary = `"$($primary.vpc_cidr)`"`n"
        $output += "vpc_cidr_dr = `"$($dr.vpc_cidr)`"`n"
        
        # Convert subnet arrays to HCL format
        $primarySubnets = $primary.subnets | ForEach-Object { "`"$_`"" } | Join-String -Separator ", "
        $drSubnets = $dr.subnets | ForEach-Object { "`"$_`"" } | Join-String -Separator ", "
        
        $output += "subnets_primary = [$primarySubnets]`n"
        $output += "subnets_dr = [$drSubnets]`n"
        
        # Convert instances to HCL format
        $primaryInstances = ConvertTo-HclInstances -instances $primary.instances
        $drInstances = ConvertTo-HclInstances -instances $dr.instances
        
        $output += "instances_primary = $primaryInstances`n"
        $output += "instances_dr = $drInstances`n"
    }
    elseif ($RootKey -eq "regions") {
        # Handle regions configuration
        $allServices = @()
        foreach ($region in $JsonContent.regions.PSObject.Properties) {
            foreach ($service in $region.Value.services) {
                if ($allServices -notcontains $service) {
                    $allServices += $service
                }
            }
        }
        
        # Convert services array to HCL format
        $servicesStr = $allServices | ForEach-Object { "`"$_`"" } | Join-String -Separator ", "
        $output += "failover_components = [$servicesStr]`n"
    }

    return $output
}

# Function to convert instances array to HCL format
function ConvertTo-HclInstances {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$instances
    )
    
    $instancesHcl = @()
    foreach ($instance in $instances) {
        $instanceHcl = "{ type = `"$($instance.type)`", count = $($instance.count), size = `"$($instance.size)`" }"
        $instancesHcl += $instanceHcl
    }
    
    return "[$($instancesHcl -join ", ")]"
}

# Main script execution

Write-Host "Converting JSON configurations to Terraform variables..."

# Check if script is running from the scripts directory
if (-not (Test-Path $testEnvJsonPath)) {
    # If not, adjust paths to be relative to project root
    $testEnvJsonPath = "./config/test-environments.json"
    $awsRegionsJsonPath = "./config/aws-regions.json"
    $tfvarsPath = "./terraform.tfvars"
}

# Read JSON configuration files
try {
    $testEnvJson = Get-Content -Path $testEnvJsonPath -Raw | ConvertFrom-Json
    $awsRegionsJson = Get-Content -Path $awsRegionsJsonPath -Raw | ConvertFrom-Json

    # Generate tfvars content
    $tfvarsContent = "# Auto-generated terraform.tfvars from JSON configuration`n"
    $tfvarsContent += "# Generated on $(Get-Date)`n`n"
    
    $tfvarsContent += ConvertTo-TfVars -JsonContent $testEnvJson -RootKey "environments"
    $tfvarsContent += ConvertTo-TfVars -JsonContent $awsRegionsJson -RootKey "regions"
    
    # Add additional default variables
    $tfvarsContent += @"

# Test parameters
test_timeout_minutes = 30
rto_threshold_minutes = 15
rpo_threshold_minutes = 60
notification_email = "team@example.com"
fis_experiments = ["cpu-stress", "network-latency"]

# Test data configuration
test_data = {
  size_mb = 100
  type    = "random"
  format  = "json"
}

validation_checks = ["data_integrity", "service_availability", "response_time"]
"@

    # Write to terraform.tfvars file
    Set-Content -Path $tfvarsPath -Value $tfvarsContent
    
    Write-Host "Successfully created terraform.tfvars file at $tfvarsPath"
} 
catch {
    Write-Error "Error processing JSON configuration: $_"
    exit 1
}