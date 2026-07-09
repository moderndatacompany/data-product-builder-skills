# Notifications

Vulcan can send notifications when certain events occur. Configure notifications and specify recipients in your configuration file.

## Notification targets

Configure notifications with notification targets. Specify targets in a project's [configuration](../README.md) file (`config.yml` or `config.py`). You can specify multiple targets for a project.

A project can specify both global and user-specific notifications. Each target's notifications are sent for all instances of each [event type](notifications.md#vulcan-event-types) (for example, notifications for `run` are sent for all of the project's environments), with exceptions for assertion failures and when an [override is configured for development](notifications.md#notifications-during-development).

Data quality failure notifications can be sent for specific models if five conditions are met:

1. A model's `owner` field is populated
2. The model executes one or more assertions
3. The owner has a user-specific notification target configured
4. The owner's notification target `notify_on` key includes `dq_failure`
5. The data quality check fails in the `prod` environment

When those conditions are met, the owner is notified if their data quality check fails in the `prod` environment.

There are four built-in notification target types: [Teams webhook](notifications.md#teams-webhook-notifications), the two [Slack notification methods](notifications.md#slack-notifications), and [email notification](notifications.md#email-notifications). Specify them in either a specific user's `notification_targets` key or the top-level `notification_targets` configuration key.

This example shows the location of both user-specific and global notification targets:

{% tabs %}
{% tab title="YAML" %}
```yaml
# User notification targets
users:
  - username: User1
    ...
    notification_targets:
      - notification_target_1
        ...
      - notification_target_2
        ...
  - username: User2
    ...
    notification_targets:
      - notification_target_1
        ...
      - notification_target_2
        ...

# Global notification targets
notification_targets:
  - notification_target_1
    ...
  - notification_target_2
    ...
```
{% endtab %}

{% tab title="Python" %}
```python
config = Config(
    ...,
    # User notification targets
    users=[
        User(
            username="User1",
            notification_targets=[
                notification_target_1(...),
                notification_target_2(...),
            ],
        ),
        User(
            username="User2",
            notification_targets=[
                notification_target_1(...),
                notification_target_2(...),
            ],
        )
    ],

    # Global notification targets
    notification_targets=[
        notification_target_1(...),
        notification_target_2(...),
    ],
    ...
)
```
{% endtab %}
{% endtabs %}

### Notifications during development

Events triggering notifications may execute repeatedly during code development. To prevent excessive notifications, Vulcan can stop all but one user's notification targets.

Specify the top-level `username` configuration key with a value also present in a user-specific notification target's `username` key to only notify that user. Specify this key in either the project configuration file or a machine-specific configuration file located in `~/.vulcan`. The latter is useful if a specific machine is always used for development.

This example stops all notifications other than those for `User1`:

{% tabs %}
{% tab title="YAML" %}
```yaml
# Top-level `username` key: only notify User1
username: User1
# User1 notification targets
users:
  - username: User1
    ...
    notification_targets:
      - notification_target_1
        ...
      - notification_target_2
        ...
```
{% endtab %}

{% tab title="Python" %}
```python
config = Config(
    ...,
    # Top-level `username` key: only notify User1
    username="User1",
    users=[
        User(
            # User1 notification targets
            username="User1",
            notification_targets=[
                notification_target_1(...),
                notification_target_2(...),
            ],
        ),
    ]
)
```
{% endtab %}
{% endtabs %}

## Vulcan event types

Vulcan notifications are triggered by events. Specify which events should trigger a notification in the notification target's `notify_on` field.

Notifications are supported for [`plan` application](../../guides/plan/plan_guide.md) start/end/failure, [`run`](../../cli.md#run) start/end/failure, and data quality start/end/failure events.

For `plan` and `run` start/end, the target environment name is included in the notification message. For failures, the Python exception or error text is included in the notification message.

This table lists each event, its associated `notify_on` value, and its notification message:

| Event                    | `notify_on` key value | Notification message                                            |
| ------------------------ | --------------------- | --------------------------------------------------------------- |
| Plan application start   | apply\_start          | "Plan apply started for environment `{environment}`."           |
| Plan application end     | apply\_end            | "Plan apply finished for environment `{environment}`."          |
| Plan application failure | apply\_failure        | "Failed to apply plan.\n{exception}"                            |
| Vulcan run start         | run\_start            | "Vulcan run started for environment `{environment}`."           |
| Vulcan run end           | run\_end              | "Vulcan run finished for environment `{environment}`."          |
| Vulcan run failure       | run\_failure          | "Failed to run Vulcan.\n{exception}"                            |
| Data quality start       | dq\_start             | "Data quality checks started for environment `{environment}`."  |
| Data quality end         | dq\_end               | "Data quality checks finished for environment `{environment}`." |
| Data quality failure     | dq\_failure           | "{dq\_error}"                                                   |

Any combination of these events can be specified in a notification target's `notify_on` field.

{% hint style="info" %}
**Data quality event names**

Use `dq_start`, `dq_end`, and `dq_failure` for data quality notifications. Older `check_start`, `check_end`, and `check_failure` values should be migrated to the `dq_*` event names.
{% endhint %}

## Teams webhook notifications

Teams webhook is a first-class notification target. Source the webhook URL from an environment variable so the value does not live in source control:

```bash
export TEAMS_WEBHOOK_URL=https://your-org.webhook.office.com/...
```

```yaml
notification_targets:
  - type: teams_webhook
    url: "{{ env_var('TEAMS_WEBHOOK_URL') }}"
    notify_on:
      - apply_failure
      - run_failure
      - dq_failure
```

You can also configure the URL directly when appropriate:

```yaml
notification_targets:
  - type: teams_webhook
    url: "https://your-org.webhook.office.com/..."
    notify_on:
      - apply_failure
      - run_failure
      - dq_failure
```

## Slack notifications

Vulcan supports two types of Slack notifications. Slack webhooks notify a Slack channel, but they cannot message specific users. The Slack Web API can notify channels or users.

### Webhook configuration

Vulcan uses Slack's "Incoming Webhooks" for webhook notifications. When you [create an incoming webhook](https://api.slack.com/messaging/webhooks) in Slack, you receive a unique URL associated with a specific Slack channel. Vulcan transmits the notification message by submitting a JSON payload to that URL.

This example shows a Slack webhook notification target. Notifications are triggered by plan application start, plan application failure, or Vulcan run start. The specification uses an environment variable `SLACK_WEBHOOK_URL` instead of hard-coding the URL:

{% tabs %}
{% tab title="YAML" %}
```yaml
notification_targets:
  - type: slack_webhook
    notify_on:
      - apply_start

      - apply_failure

      - run_start
    url: "{{ env_var('SLACK_WEBHOOK_URL') }}"
```
{% endtab %}

{% tab title="Python" %}
```python
notification_targets=[
    SlackWebhookNotificationTarget(
        notify_on=["apply_start", "apply_failure", "run_start"],
        url=os.getenv("SLACK_WEBHOOK_URL"),
    )
]
```
{% endtab %}
{% endtabs %}

### API configuration

To notify users, use the Slack API notification target. This requires a Slack API token, which can be used for multiple notification targets with different channels or users. See [Slack's official documentation](https://api.slack.com/tutorials/tracks/getting-a-token) for information on getting an API token.

This example shows a Slack API notification target. Notifications are triggered by plan application start, plan application end, or data quality failure. The specification uses an environment variable `SLACK_API_TOKEN` instead of hard-coding the token:

{% tabs %}
{% tab title="YAML" %}
```yaml
notification_targets:
  - type: slack_api
    notify_on:
      - apply_start

      - apply_end

      - dq_failure
    token: "{{ env_var('SLACK_API_TOKEN') }}"
    channel: "UXXXXXXXXX"  # Channel or a user's Slack member ID
```
{% endtab %}

{% tab title="Python" %}
```python
notification_targets=[
    SlackApiNotificationTarget(
        notify_on=["apply_start", "apply_end", "dq_failure"],
        token=os.getenv("SLACK_API_TOKEN"),
        channel="UXXXXXXXXX",  # Channel or a user's Slack member ID
    )
]
```
{% endtab %}
{% endtabs %}

## Email notifications

Vulcan supports notifications via email. The notification target specifies the SMTP host, user, password, and sender address. A target can notify multiple recipient email addresses.

This example shows an email notification target, where `sushi@example.com` emails `data-team@example.com` on Vulcan run failure. The specification uses environment variables `SMTP_HOST`, `SMTP_USER`, and `SMTP_PASSWORD` instead of hard-coding the values:

{% tabs %}
{% tab title="YAML" %}
```yaml
notification_targets:
  - type: smtp
    notify_on:
      - run_failure
    host: "{{ env_var('SMTP_HOST') }}"
    user: "{{ env_var('SMTP_USER') }}"
    password: "{{ env_var('SMTP_PASSWORD') }}"
    sender: sushi@example.com
    recipients:
      - data-team@example.com
```
{% endtab %}

{% tab title="Python" %}
```python
notification_targets=[
    BasicSMTPNotificationTarget(
        notify_on=["run_failure"],
        host=os.getenv("SMTP_HOST"),
        user=os.getenv("SMTP_USER"),
        password=os.getenv("SMTP_PASSWORD"),
        sender="notifications@example.com",
        recipients=[
            "data-team@example.com",
        ],
    )
]
```
{% endtab %}
{% endtabs %}

## Advanced usage

### Overriding notification targets

In Python configuration files, configure new notification targets to send custom messages.

To customize a notification, create a new notification target class as a subclass of one of the three target classes described above (`SlackWebhookNotificationTarget`, `SlackApiNotificationTarget`, or `BasicSMTPNotificationTarget`).

Each of those notification target classes is a subclass of `BaseNotificationTarget`, which contains a `notify` function corresponding to each event type. This table lists the notification functions, along with the contextual information available to them at calling time (for example, the environment name for start/end events):

| Function name          | Contextual information               |
| ---------------------- | ------------------------------------ |
| notify\_apply\_start   | Environment name: `env`              |
| notify\_apply\_end     | Environment name: `env`              |
| notify\_apply\_failure | Exception stack trace: `exc`         |
| notify\_run\_start     | Environment name: `env`              |
| notify\_run\_end       | Environment name: `env`              |
| notify\_run\_failure   | Exception stack trace: `exc`         |
| notify\_dq\_failure    | Data quality error trace: `dq_error` |

This example creates a new notification target class `CustomSMTPNotificationTarget`.

It overrides the default `notify_run_failure` function to read a log file `"/home/vulcan/vulcan.log"` and append its contents to the exception stack trace `exc`:

{% tabs %}
{% tab title="Python" %}

{% endtab %}
{% endtabs %}

```python
from vulcan.core.notification_target import BasicSMTPNotificationTarget

class CustomSMTPNotificationTarget(BasicSMTPNotificationTarget):
    def notify_run_failure(self, exc: str) -> None:
        with open("/home/vulcan/vulcan.log", "r", encoding="utf-8") as f:
            msg = f"{exc}\n\nLogs:\n{f.read()}"
        super().notify_run_failure(msg)
```

Use this new class by specifying it as a notification target in the configuration file:

{% tabs %}
{% tab title="Python" %}
```python
notification_targets=[
    CustomSMTPNotificationTarget(
        notify_on=["run_failure"],
        host=os.getenv("SMTP_HOST"),
        user=os.getenv("SMTP_USER"),
        password=os.getenv("SMTP_PASSWORD"),
        sender="notifications@example.com",
        recipients=[
            "data-team@example.com",
        ],
    )
]
```
{% endtab %}
{% endtabs %}
