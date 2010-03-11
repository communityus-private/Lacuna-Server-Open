use lib '../lib';
use Test::More tests => 15;
use Test::Deep;
use Lacuna::DB;
use Config::JSON;
use Data::Dumper;
use DateTime;
use 5.010;

my $config = Config::JSON->new("/data/Lacuna-Server/etc/lacuna.conf");
my $db = Lacuna::DB->new( access_key => $config->get('access_key'), secret_key => $config->get('secret_key'), cache_servers => $config->get('memcached'));

my $human = $db->domain('species')->find('human_species');
my $home = $human->find_home_planet;
my $empire = Lacuna::DB::Empire->found(
    $db,
    $home,
    $human,
    {
        name        => 'The Big Stats Tester',
        password    => Lacuna::DB::Empire->encrypt_password('123qwe'),
    }
    );
my $initial_status = $empire->home_planet->get_extended_status;

my $wheat = Lacuna::DB::Building::Food::Farm::Wheat->new(
    simpledb        => $db,
    x               => 0,
    y               => 1,
    class           => 'Lacuna::DB::Building::Food::Farm::Wheat',
    date_created    => DateTime->now,
    body_id         => $home->id,
    empire_id       => $empire->id,
    level           => 0,
);
$empire->home_planet->build_building($wheat);
$wheat->finish_upgrade;


my $after_wheat = $wheat->body->get_extended_status;

say Dumper($after_wheat);

cmp_ok($initial_status->{food_hour}, '<', $after_wheat->{food_hour}, "food_hour raised");
cmp_ok($initial_status->{ore_hour}, '>', $after_wheat->{ore_hour}, "ore_hour lowered");
cmp_ok($initial_status->{energy_hour}, '>', $after_wheat->{energy_hour}, "energy_hour lowered");
cmp_ok($initial_status->{water_hour}, '>', $after_wheat->{water_hour}, "water_hour lowered");
cmp_ok($initial_status->{waste_hour}, '<', $after_wheat->{waste_hour}, "waste_hour raised");


my $water = Lacuna::DB::Building::Water::Purification->new(
    simpledb        => $db,
    x               => 0,
    y               => 2,
    class           => 'Lacuna::DB::Building::Water::Purification',
    date_created    => DateTime->now,
    body_id         => $home->id,
    empire_id       => $empire->id,
    level           => 0,
);
$wheat->body->build_building($water);
$water->finish_upgrade;

my $after_water = $water->body->get_extended_status;

say Dumper($after_water);

cmp_ok($after_wheat->{food_hour}, '>', $after_water->{food_hour}, "food_hour lowered");
cmp_ok($after_wheat->{ore_hour}, '>', $after_water->{ore_hour}, "ore_hour lowered");
cmp_ok($after_wheat->{energy_hour}, '>', $after_water->{energy_hour}, "energy_hour lowered");
cmp_ok($after_wheat->{water_hour}, '<', $after_water->{water_hour}, "water_hour raised");
cmp_ok($after_wheat->{waste_hour}, '<', $after_water->{waste_hour}, "waste_hour raised");

my $we = Lacuna::DB::Building::Energy::Waste->new(
    simpledb        => $db,
    x               => 0,
    y               => 3,
    class           => 'Lacuna::DB::Building::Energy::Waste',
    date_created    => DateTime->now,
    body_id         => $home->id,
    empire_id       => $empire->id,
    level           => 0,
);
$water->body->build_building($we);
$we->finish_upgrade;

my $after_we = $we->body->get_extended_status;

say Dumper($after_we);

cmp_ok($after_water->{food_hour}, '>', $after_we->{food_hour}, "food_hour lowered");
cmp_ok($after_water->{ore_hour}, '>', $after_we->{ore_hour}, "ore_hour lowered");
cmp_ok($after_water->{energy_hour}, '<', $after_we->{energy_hour}, "energy_hour raised");
cmp_ok($after_water->{water_hour}, '>', $after_we->{water_hour}, "water_hour lowered");
cmp_ok($after_water->{waste_hour}, '>', $after_we->{waste_hour}, "waste_hour lowered");


$empire->delete;

