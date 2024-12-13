# AI repo feedback

This is a set of shell and Python scripts that provides formative
feedback on Git repositories containing Java projects.

The script can be executed to output Markdown or HTML regarding
a specified local Git repository.
It can also be provided with a list of repository URLs and email addresses.
In this case it will assess each repository and send email to the
specified email address.

To run the script you must set the environment variable `OPENAI_API_KEY`
to an OpenAI API key that provides access to the GPT models.

Furthermore, to send emails you must set the environment variables
`SMTP_SERVER`, `SMTP_USERNAME`, and `SMTP_PASSWORD` to the values
of an SMTP server and credentials that allow you to send out email.

## Usage examples

```sh
export SMTP_SERVER=smtp.example.com
export SMTP_USERNAME=myname
export SMTP_PASSWORD=mypassword
export OPENAI_API_KEY=sk-.......

# Create a Markdown report from a local repo
feedback.sh -d repo-dir >comments.md

# Send out reports 
feedback.sh -l repo-list -f mary@example.com -F 'Mary Zhu' -s Feedback
```

## Contributing back
Contributions to this project via GitHub pull requests are welcomed,
provided they are general enough to be used in diverse contexts.
For example these could improve the output, change prompting to improve
the given feedback, add new feedback types, of support another programming
language or framework.
