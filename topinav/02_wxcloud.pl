#!/usr/bin/perl
use strict;
use warnings;
use Wx;

use Topinav::MainWindow;

# ================= main cycle =================

package main;

my $app = MainWindow->new;
$app->MainLoop;
