package Lacuna::Role::Ship::Arrive::DamageBuilding;

use strict;
use Moose::Role;
use Lacuna::Util qw(randint);
use DateTime;

after handle_arrival_procedures => sub {
    my ($self) = @_;

    # we're coming home
    return if ($self->direction eq 'in');

#Check if attack group
# If groups of snarks
#   check if reasonable to assume zero out everything on planet (depends on type, etc...)
#   if not, go thru an attack for each.
# else return and go to next step
# 1) Group of snarks?
# 2) How many target buildings?
# 3) See if reasonable that buildings get zeroed?
    my %snarks = (
        snarks => {
            count => 0,
            target => [],
            display => "Snark Warheads",
        },
        observatory_seeker => {
            count => 0,
            target => [],
            display => "Observatory Seekers",
        },
        spaceport_seeker => {
            count => 0,
            target => [],
            display => "Spaceport Seekers",
        },
        security_ministry_seeker => {
            count => 0,
            target => [],
            display => "Security Ministry Seekers",
        },
    );
    if ($self->type eq "attack_group") {
        my $snarkit = 0;
        my $payload = $self->payload;
        my %del_keys;
        for my $fleet (keys %{$payload->{fleet}}) {
            if ($payload->{fleet}->{$fleet}->{type} eq "snark") {
                $snarks{snarks}->{count} += $payload->{fleet}->{$fleet}->{quantity};
                $del_keys{$fleet} = $payload->{fleet}->{$fleet}->{quantity};
                $snarkit = 1;
            }
            elsif ($payload->{fleet}->{$fleet}->{type} eq "snark2") {
                $snarks{snarks}->{count} += 4 * $payload->{fleet}->{$fleet}->{quantity};
                $del_keys{$fleet} = $payload->{fleet}->{$fleet}->{quantity};
                $snarkit = 1;
            }
            elsif ($payload->{fleet}->{$fleet}->{type} eq "snark3") {
                $snarks{snarks}->{count} += 9 * $payload->{fleet}->{$fleet}->{quantity};
                $del_keys{$fleet} = $payload->{fleet}->{$fleet}->{quantity};
                $snarkit = 1;
            }
            elsif ($payload->{fleet}->{$fleet}->{type} eq "observatory_seeker") {
                $snarks{observatory_seeker}->{count} += $payload->{fleet}->{$fleet}->{quantity};
                $snarks{observatory_seeker}->{target} = $payload->{fleet}->{$fleet}->{target_building};
                $del_keys{$fleet} = $payload->{fleet}->{$fleet}->{quantity};
                $snarkit = 1;
            }
            elsif ($payload->{fleet}->{$fleet}->{type} eq "security_ministry_seeker") {
                $snarks{security_ministry_seeker}->{count} += $payload->{fleet}->{$fleet}->{quantity};
                $snarks{security_ministry_seeker}->{target} = $payload->{fleet}->{$fleet}->{target_building};
                $del_keys{$fleet} = $payload->{fleet}->{$fleet}->{quantity};
                $snarkit = 1;
            }
            elsif ($payload->{fleet}->{$fleet}->{type} eq "spaceport_seeker") {
                $snarks{spaceport_seeker}->{count} += $payload->{fleet}->{$fleet}->{quantity};
                $snarks{spaceport_seeker}->{target} = $payload->{fleet}->{$fleet}->{target_building};
                $del_keys{$fleet} = $payload->{fleet}->{$fleet}->{quantity};
                $snarkit = 1;
            }
        }
        if ($snarkit) {
            my $snark_impacts = 0;
            for my $key (keys %del_keys) {
                delete $payload->{fleet}->{$key};
                $snark_impacts += $del_keys{$key};
            }
            $self->payload($payload);
            $self->number_of_docks($self->number_of_docks - $snark_impacts);
            $self->update;
        }
        else {
            return unless $snarkit;
        }
    }
    else {
        my $type = $self->type;
        if ($type eq "snark") {
            $snarks{snarks}->{count} = 1;
        }
        elsif ($type eq "snark2") {
            $snarks{snarks}->{count} = 4;
        }
        elsif ($type eq "snark3") {
            $snarks{snarks}->{count} = 9;
        }
        elsif ($type eq "observatory_seeker") {
            $snarks{observatory_seeker}->{count} = 1;
            $snarks{observatory_seeker}->{target} = $self->target_building;
        }
        elsif ($type eq "security_ministry_seeker") {
            $snarks{security_ministry_seeker}->{count} = 1;
            $snarks{security_ministry_seeker}->{target} = $self->target_building;
        }
        elsif ($type eq "spaceport_seeker") {
            $snarks{spaceport_seeker}->{count} = 1;
            $snarks{spaceport_seeker}->{target} = $self->target_building;
        }
    }
    my $body_attacked = $self->foreign_body;
    my @all_builds =
            sort {
                $b->efficiency <=> $a->efficiency ||
                rand() <=> rand()
            }
            grep {
                ($_->efficiency > 0) and
                ($_->class ne 'Lacuna::DB::Result::Building::Permanent::Crater') and
                ($_->class ne 'Lacuna::DB::Result::Building::DeployedBleeder') and
                ($_->class ne 'Lacuna::DB::Result::Building::TheDillonForge')
            } @{$body_attacked->building_cache};

    my $report;
  
    push @{$report}, (['Type','Number']);
    for my $sn_type ("observatory_seeker", "security_ministry_seeker",
                      "spaceport_seeker", "snarks") {
        if ($snarks{$sn_type}->{count} > 0) {
            push @{$report}, [
                $snarks{$sn_type}->{display},
                $snarks{$sn_type}->{count},
            ];
        }
    }
    push @{$report}, (['Buildings', scalar @all_builds]);

    if ( $snarks{snarks}->{count}/4 > scalar @all_builds) {
        for my $building (@all_builds) {
            $building->spend_efficiency(100);
            $building->update;
            push @{$report}, [
                $building->name,
                100,
            ];
        }
    }
    else {
        my $building;
        my %treport;
        for my $sn_type ("observatory_seeker", "security_ministry_seeker",
                      "spaceport_seeker", "snarks") {
            my @tbuilds;
            if ($snarks{$sn_type}->{count}) {
                for my $tb ( @{$snarks{$sn_type}->{target}}) {
                    my @temp = $body_attacked->get_buildings_of_class($tb);
                    if (@temp) {
                      push @tbuilds, @temp;
                    }
                }
            }
            else {
                @tbuilds = @all_builds;
            }
            if ($snarks{$sn_type}->{count}/4 > scalar @tbuilds) {
                for $building (@tbuilds) {
                    $building->spend_efficiency(100)->update;
                    $treport{"$building->name"} = 100;
                }
            }
            else {
                BOOM: for (1..$snarks{$sn_type}->{count}) {
                    my $amount = randint(10,70);
                    ($building) = 
                        sort {
                            $b->efficiency <=> $a->efficiency ||
                            rand() <=> rand()
                        }
                        grep {
                            ($_->efficiency > 0)
                        } @tbuilds;
                    if ($building) {
                        $building->spend_efficiency($amount)->update;
                        $treport{"$building->name"} = 100 - $building->efficiency;
                    }
                    else {
                        last BOOM;
                    }
                }
            }
        }
        for my $key (sort keys %treport) {
            push @{$report}, [
                $key,
                $treport{"$key"},
            ];
            
        }
    }

    
#Send email, n19 and battle log
    # let everyone know what's going on
    unless ($body_attacked->empire->skip_attack_messages) {
        $body_attacked->empire->send_predefined_message(
        tags        => ['Attack','Alert'],
        filename    => 'ship_hit_building.txt',
        params      => [$self->type_formatted, $body_attacked->id,
                        $body_attacked->name, $self->body->empire_id, $self->body->empire->name],
        attachments => { table => $report },
            );
    }
    unless ($self->body->empire->skip_attack_messages) {
        $self->body->empire->send_predefined_message(
            tags        => ['Attack','Alert'],
            filename    => 'our_ship_hit_building.txt',
            params      => [$self->type_formatted, $body_attacked->x, $body_attacked->y,
                            $body_attacked->name ],
            attachments => { table => $report },
            );
    }
    $body_attacked->add_news(70, sprintf('An attack ship screamed out of the sky and damaged buildings on %s.', $body_attacked->name));

    my $log = Lacuna->db->resultset('Log::Battles')->new({
        date_stamp => DateTime->now,
        attacking_empire_id     => $self->body->empire_id,
        attacking_empire_name   => $self->body->empire->name,
        attacking_body_id       => $self->body_id,
        attacking_body_name     => $self->body->name,
        attacking_unit_name     => $self->name,
        attacking_type          => $self->type_formatted,
        defending_empire_id     => $body_attacked->empire_id,
        defending_empire_name   => $body_attacked->empire->name,
        defending_body_id       => $body_attacked->id,
        defending_body_name     => $body_attacked->name,
        defending_unit_name     => sprintf("%s (%d,%d)", "ouch", 0, 0),
        defending_type          => "building_name",
        attacked_empire_id      => $body_attacked->empire_id,
        attacked_empire_name    => $body_attacked->empire->name,
        attacked_body_id        => $body_attacked->id,
        attacked_body_name      => $body_attacked->name,
        victory_to              => 'attacker',
    });

    $log->insert;
    if ($self->type ne "attack_group" or $self->number_of_docks < 1) {
        $self->delete;
        confess [-1];
    }
};

1;
