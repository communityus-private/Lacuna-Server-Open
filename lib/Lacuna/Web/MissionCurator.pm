package Lacuna::Web::MissionCurator;

use Moose;
use utf8;
no warnings qw(uninitialized);
extends qw(Lacuna::Web);
use Lacuna::Constants qw(FOOD_TYPES ORE_TYPES);
use feature "switch";
use Module::Find;
use UUID::Tiny ':std';
use Lacuna::Util qw(format_date);
use List::Util qw(sum);

sub www_add_essentia {
    my ($self, $request) = @_;
    my $empires = Lacuna->db->resultset('Lacuna::DB::Result::Empire');
    my $empire = $empires->find($request->param('id'));
    unless (defined $empire) {
        confess [404, 'Empire not found.'];
    }
    my $curator = $empires->search({name=>$request->user},{rows=>1})->single;
    my $jt = $empires->find(2);
    $empire->add_essentia(100, 'Mission Pack Approved By '.$curator->name)->update;
    $empire->send_message(
        from    => $curator,
        subject => 'Mission Bounty',
        message => 'I have approved your mission pack and awarded you 100 essentia.',
    );
    $jt->send_message(
        from    => $curator,
        subject => 'Mission Bounty',
        message => 'I have approved a mission pack for '.$empire->name.'.',
    );
    my $recent = Lacuna->db->resultset('Lacuna::DB::Result::Log::Essentia')->search({ empire_id => $curator->id, description => 'Mission Curator', date_stamp => { '>' => DateTime->now->subtract(days => 7)}})->count;
    $curator->add_essentia(100, 'Mission Curator') unless $recent;
    return $self->www_default($request, 'Essentia Added');
}

sub www_default {
    my ($self, $request, $message) = @_;
    my $page_number = $request->param('page_number') || 1;
    my $empires = Lacuna->db->resultset('Lacuna::DB::Result::Empire')->search(undef, {order_by => ['name'], rows => 25, page => $page_number });
    my $name = $request->param('name') || '';
    if ($name) {
        $empires = $empires->search({name => { like => $name.'%' }});
    }
    my $out = $message.'<h1>Add Mission Essentia</h1>';
    $out .= '<form method="post" action="/admin/search/empires"><input name="name" value="'.$name.'"><input type="submit" value="search"></form>';
    $out .= '<table style="width: 100%;"><tr><th>Id</th><th>Name</th><th>Species</th><th>Home</th><th>Last Login</th></tr>';
    while (my $empire = $empires->next) {
        $out .= sprintf('<tr><td>%s</td><td>%s</td><td><a href="/missioncurator/add_essentia?id=%s">Add Essentia</a></td></tr>', $empire->name, $empire->email, $empire->id);
    }
    $out .= '</table>';
    $out .= $self->format_paginator('search/empires', 'name', $name, $page_number);
    return $self->wrap($out);
}


sub format_paginator {
    my ($self, $method, $key, $value, $page_number) = @_;
    my $out = '<fieldset><legend>Page: '.$page_number.'</legend>';
    $out .= '<a href="/admin/'.$method.'?'.$key.'='.$value.';page_number='.($page_number - 1).'">&lt; Previous</a> | ';
    $out .= '<a href="/admin/'.$method.'?'.$key.'='.$value.';page_number='.($page_number + 1).'">Next &gt;</a> ';
    $out .= '<form method="post" style="display: inline;" action="/admin/'.$method.'"><input name="page_number" value="'.$page_number.'" style="width: 30px;"><input type="hidden" name="'.$key.'" value="'.$value.'"><input type="submit" value="go"></form>';
    $out .= '</fieldset>';
    return $out;
}


sub wrap {
    my ($self, $content) = @_;
    return $self->wrapper($content .' <fieldset><legend>Mission Utilities</legend>
        <ul>
            <li><a href="https://github.com/plainblack/Lacuna-Mission">Mission Repository</a></li>
            <li><a href="http://community.lacunaexpanse.com/forums/missions">Mission Forum</a> [<a href="mailto:missions@lacunaexpanse.com">missions@lacunaexpanse.com</a>]</li>
            <li><a href="http://community.lacunaexpanse.com/forums/mission-curators">Curators Forum</a> [<a href="mailto:missioncurators@lacunaexpanse.com">missioncurators@lacunaexpanse.com</a>]</li>
            <li><a href="http://community.lacunaexpanse.com/wiki/mission-editor">Mission Editor</a></li>
        </ul>
        </fieldset>',
    { title => 'Admin Console'}
    );
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

