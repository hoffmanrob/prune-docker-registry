# prune-docker-registry
Query a v2 docker-registry and generate a list of images to delete.

This script is a wrapper to pass unwanted images to docker_delete_registry_image.sh, available at <https://github.com/burnettk/delete-docker-registry-image>.

Based on a minimum number of tags to keep, this script will:

1. Query a version 2 private docker-registry.
1. Create a list of images that can be safely deleted.
1. Pass that list to delete-docker-registry-image.sh, which will do the complicated task of actually removing those images from the registry. 

**Non-trival notes:**

The docker-registry will be shut down when removing images to avoid corruption.

The gem "naturally" is used to sort version numbers. Your version numbering scheme must be consistent within, but not across, each repository or naturally will get confused. If naturally gets confused sorting the tags of a repository, that repository will be excluded from pruning.


## Requirements

* docker-registry >= 2.0
* ruby >= 2.0
* gem install naturally
* <https://github.com/burnettk/delete-docker-registry-image>
* Must run on the host of a docker-registry using filesystem storage for its images.


## Configure

Set the following variables at the top of the script to match your environment:

```
$num_tags_to_keep = 20
$registry_container_name = "registry-2"
$registry_url = "https://localhost:5000"
$delete_image_script = "/path/to/delete-docker-registry-image.sh"
```

Should you have a repository you do not want pruned, add it to the following array:

```
$prune_exclude = []
```
