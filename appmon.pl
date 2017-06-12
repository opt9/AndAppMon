#!/usr/bin/env perl

use strict;
use warnings;
use YAML qw(LoadFile);
use WWW::Mechanize;
use Digest::MD5 qw(md5_hex);
#use Growl::NotifySend;
use Email::Sender::Transport::SMTP;
use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;
use Data::Dumper;


## Initialization
my $DEBUG = 1;

my $config = LoadFile('config.yml');
my $login    = $config->{login};
my $password = $config->{password};
my $filename = "ver.txt";
my $ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36 OPR/45.0.2552.888';

my $mech = WWW::Mechanize->new( 
    agent => $ua, 
    cookie_jar => {}
    );
### read old version info
open(my $rd, '<', $filename) or die "Can't open '$filename': $!";
my $old = $rd->getline();
print STDERR $old if $DEBUG;
close($rd);
chomp($old);


## Do Login
my $login_url = 'https://www.appannie.com/account/login/?_ref=header';
$mech->get($login_url);
$mech->submit_form(
    form_number => 1,
    fields      => {
                    username => $login,
                    password => $password
                    },
);
die unless ($mech->success);
print STDERR "Login success.\n" if $DEBUG;


## Get Version Info and Store it
my $app_url = 'https://www.appannie.com/apps/google-play/app/' . $config->{app} . '/details/';
$mech->get($app_url);
my $c = $mech->content;
print STDERR Dumper $c if $DEBUG;
$c =~ m{<h5>(.*?)</h5>}s or die "Can't find the version info.\n";
my $ver = $1;
my $new = md5_hex($ver);
print STDERR $ver . "\n" if $DEBUG;
print STDERR $new . "\n" if $DEBUG;
### write new version info
open(my $wr, '>', $filename) or die "Can't open '$filename': $!";
print $wr $new . "\n";
close($wr);


## Diff the version
if ($new eq $old) {
    print STDERR "Skip.\n" if $DEBUG;
} else {
    print STDERR "New version released.\n" if $DEBUG;

    ### Send the notification
    ### plz, use https://github.com/opt9/Perl-Growl-NotifySend version
    # Growl::NotifySend -> show (
    #     urgency => 'low',
    #     expire_time => '3000',
    #     icon => 'phone',
    #     summary => 'Android App',
    #     body => $ver
    #     ) if $DEBUG;
    
    my $transport = Email::Sender::Transport::SMTP->new({
        host => $config->{server},
        port => $config->{port},
    });
    my $email = Email::Simple->create(
        header => [
          To           => $config->{to},
          From         => $config->{from},
          Subject      => "[Mobsec] New Android App $ver released",
        ],
        body => "Android App $ver released.\nPlease download it from http://apk-dl.com/" . $config->{app} . "\n",
    );
    my $ret = sendmail($email, { transport => $transport});
    print STDERR Dumper $ret if $DEBUG;
}
