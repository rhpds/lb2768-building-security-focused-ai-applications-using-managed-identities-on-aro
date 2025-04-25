# Important notes

OpenCV for Python comes in two flavors, standard and headless. The Headless version is the one required inside a container image, otherwise the command `import cv2`  will fail.

That's because the standard version has dependencies on OS packages related to display, which you obviously don't have in a container. However, it i listed as a dependency by several other libraries which expect you to run on a desktop/laptop! Therefore we need to make sure only the headless version is installed.

The `requirements.txt` file used to build the container image is generated in this way:

- Create a Pipfile with the needed packages
- Lock the packages (`pipenv lock`)
- Create the requirement.txt with `pipenv requirements > requirements.txt`
- Edit `requirements.txt` and remove the package `opencv-python` (which has been "injected" as a dependency), it was not in the Pipfile, but keep `opencv-python-headless`
- `requirements.txt` content will be installed when the container is built with the option `no-dependencies` to avoid unwanted packages to come back... This option is really needed, otherwise pip will install the standard opencv version again as a dependency...

## Build the image

`podman build -t ghcr.io/rh-mobb/rhoai-lab-insurance-claim-workbench:miwi .`

on a mac

`podman build --platform linux/amd64 -t ghcr.io/rh-mobb/rhoai-lab-insurance-claim-workbench:miwi .`



```
pipenv
openai

# torch==2.2.2+cpu --extra-index-url https://download.pytorch.org/whl/cpu

azure-identity
azure-search-documents
https://github.com/paulczar/langchain/releases/download/azure-ai-search/langchain_community-0.3.21-py3-none-any.whl
langchain-openai
```