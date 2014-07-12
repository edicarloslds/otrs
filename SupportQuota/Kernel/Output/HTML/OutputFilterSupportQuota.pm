# --
# Kernel/Output/HTML/OutputFilterSupportQuota.pm
# Copyright (C) 2001-2014 Deny Dias, http://mexapi.macpress.com.br/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilterSupportQuota;

use strict;
use warnings;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    for my $Needed (
        qw(ConfigObject DBObject LayoutObject)
        )
    {
        if ( !$Self->{$Needed} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Needed!" );
        }
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get customer_id
    my $Cid = '';
    my $SQL = "SELECT customer_id FROM ticket WHERE id = '" . $Self->{TicketID} . "'";
    $Self->{DBObject}->Prepare(SQL => $SQL, Limit => 1);
    while (my @Row = $Self->{DBObject}->FetchrowArray()) {
      $Cid = $Row[0];
    }

    # get contract quota
    my $Cquota = '';
    $SQL = "SELECT quota FROM customer_company WHERE customer_id = '" . $Cid . "'";
    $Self->{DBObject}->Prepare(SQL => $SQL, Limit => 1);
    while (my @Row = $Self->{DBObject}->FetchrowArray()) {
      $Cquota = $Row[0];
    }

    # get used quota for the accounting period (current month)
    my $Uquota = '';
    $SQL = "
        SELECT
            sum(ta.time_unit)
        FROM ticket t
            left join time_accounting ta on ta.ticket_id=t.id
        WHERE
            ta.time_unit IS NOT NULL
            AND t.customer_id='" . $Cid . "'
            AND year(t.create_time) = year(now())
            AND month(t.create_time) = month(now())
        GROUP BY
          t.customer_id";
    $Self->{DBObject}->Prepare(SQL => $SQL, Limit => 1);
    while (my @Row = $Self->{DBObject}->FetchrowArray()) {
      $Uquota = $Row[0];
    }

    # format and calculate remaining data
    my $ContractQuota = sprintf '%.1f', $Cquota;
    my $UsedQuota =  sprintf '%.1f', $Uquota;
    my $AvailableQuota = sprintf '%.1f', $Cquota - $Uquota;

    my $HTML = '
            <div class="WidgetSimple">
                <div class="Header">
                    <h2>Cota de Suporte do Cliente</h2>
                </div>
                <div class="Content">
                    <fieldset class="TableLike FixedLabelSmall Narrow">
                        <label>Dispon&iacute;vel:</label>
                        <p class="Value">' . $AvailableQuota . '</p>
                        <div class="Clear"></div>
                        <label>Utilizado:</label>
                        <p class="Value">' . $UsedQuota . '</p>
                        <div class="Clear"></div>
                        <label>Contratado:</label>
                        <p class="Value">' . $ContractQuota . '</p>
                        <div class="Clear"></div>
                    </fieldset>
                </div>
            </div>
    ';

    # add information
    ${ $Param{Data} } =~ s{
        (<\!--\sdtl:block:CustomerTable\s-->)
    }
    {
        $HTML $1
    }sxim;

    return $Param{Data};
}

1;