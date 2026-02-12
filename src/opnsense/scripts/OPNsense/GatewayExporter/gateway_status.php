#!/usr/local/bin/php
<?php

/*
 * Copyright (C) 2026 Brendan Bank
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

require_once 'config.inc';
require_once 'util.inc';
require_once 'interfaces.inc';

$gateways_status = return_gateways_status();
$gateways_config = (new \OPNsense\Routing\Gateways())->gatewaysIndexedByName();

$rows = [];

foreach ($gateways_config as $gname => $gw) {
    $entry = [
        'name' => $gname,
        'description' => !empty($gw['descr']) ? $gw['descr'] : $gname,
    ];

    if (!empty($gateways_status[$gname])) {
        $gs = $gateways_status[$gname];
        $entry['status'] = $gs['status'];
        $entry['delay'] = $gs['delay'];
        $entry['stddev'] = $gs['stddev'];
        $entry['loss'] = $gs['loss'];
        $entry['monitor'] = $gs['monitor'] !== '~' ? $gs['monitor'] : '';

        switch ($gs['status']) {
            case 'none':
                $entry['status_translated'] = 'Online';
                break;
            case 'force_down':
                $entry['status_translated'] = 'Offline (forced)';
                break;
            case 'down':
                $entry['status_translated'] = 'Offline';
                break;
            case 'delay':
                $entry['status_translated'] = 'Latency';
                break;
            case 'loss':
                $entry['status_translated'] = 'Packetloss';
                break;
            case 'delay+loss':
                $entry['status_translated'] = 'Latency, Packetloss';
                break;
            default:
                $entry['status_translated'] = 'Pending';
                break;
        }
    } else {
        $entry['status'] = 'pending';
        $entry['status_translated'] = 'Pending';
        $entry['delay'] = '~';
        $entry['stddev'] = '~';
        $entry['loss'] = '~';
        $entry['monitor'] = '';
    }

    $rows[] = $entry;
}

$result = [
    'rows' => $rows,
    'node_exporter_installed' => file_exists('/usr/local/etc/inc/plugins.inc.d/node_exporter.inc'),
];

echo json_encode($result) . PHP_EOL;
