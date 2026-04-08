Before claiming infrastructure work is complete, verify:

1. If editing k8s manifests, have you validated the YAML? Does the resource exist in the target namespace? Are image tags pinned, not floating?

2. If editing Dockerfiles, does the image build? Have you checked the final image size isn't bloated by build dependencies?

3. If touching secrets or env vars, are you using variable substitution? Never hardcode values. Check the diff for leaked secrets before committing.

4. If deploying, what is the rollback path? What happens if this fails mid-deploy?
