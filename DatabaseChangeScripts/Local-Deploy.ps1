cls
$ENV:DBSERVERA = "localhost"
$ENV:DBSERVERB = "ignore"
$ENV:DB = "Billing"
$ENV:WORKSPACE = $PSCommandPath.Substring(0, $PSCommandPath.IndexOf("\V1.0.0"))
$ENV:PIPELINE_VERSION = "LocalDeploy"

. "$ENV:WORKSPACE\V1.0.0\FMI.Billing.Database\Powershell\Jenkins-Deploy.ps1"