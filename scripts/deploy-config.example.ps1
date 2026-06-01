# Bu faylı deploy-config.local.ps1 adı ilə kopyalayın və dəyərləri doldurun.
# deploy-config.local.ps1 .gitignore-da saxlanılır.

$ApiDomain      = 'psapi.sayt.cam'
$WebDomain      = 'ps.sayt.cam'

$ServerDbHost     = 'localhost'
$ServerDbName     = 'psapi_psclub'
$ServerDbUser     = 'psapi_psclub'
$ServerDbPassword = 'BURAYA_SIFRE'

# server-setup.php — server .env MIGRATE_KEY ilə eyni olmalıdır
$ServerMigrateKey = 'BURAYA_MIGRATE_ACARI'
