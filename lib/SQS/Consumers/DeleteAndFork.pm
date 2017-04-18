package SQS::Consumers::DeleteAndFork;
use Moose;
use namespace::autoclean;

sub fetch_message {
    my $self = shift;
    my $worker = shift;

    $worker->log->debug('Receiving Messages');
    my $message_pack = $worker->receive_message();

    $worker->log->debug(sprintf "Got %d messages", scalar(@{ $message_pack->Messages }));

    foreach my $message (@{$message_pack->Messages}) {
        $worker->log->info("Processing message " . $message->ReceiptHandle);
        # We have to delete the message from the queue in any case, but we don't 
        # want to wait for the process to finish (if the process is longer than
        # the messages visibility timeout, then the message will possibly be redelivered
        $worker->delete_message($message);

        my $chld = fork;
        if ($chld == -1) {
            $worker->log->error("problem forking: ", $!);
        } elsif ($chld == 0) {
          eval {
            $worker->process_message($message);
          };
          if ($@) {
            $worker->log->error("Exception caught: " . $@);
            $worker->on_failure->($worker, $message);
          }
          # Exit the child (nothing more to do in childs)
          exit;
        } else {
          # Nothing special to do in the parent. Just keep on processing messages
        }
    }
}

__PACKAGE__->meta->make_immutable;
1;
