#!/usr/bin/ruby

## Copyright 2015 Rob Hoffman, with gratitude to CACI Limited for permission to open source.
## 
## Documentation:
##   https://github.com/hoffmanrob/prune-docker-registry

require "net/https"
require "uri"
require 'naturally'
require 'json'


$num_tags_to_keep = 20
$registry_container_name = "registry-2"
$registry_url = "https://some.registry.server:5000"
$delete_image_script = "/path/to/delete-docker-registry-image.sh"
$prune_exclude = []

## Don't use the proxy even if http_proxy is defined on the host.
$proxy_addr = nil

def get_repositories(registry_url)
  uri = URI.parse("#{$registry_url}/v2/_catalog")
  http = Net::HTTP.new(uri.host, uri.port, $proxy_addr)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  json = response.body

  ## Convert the json to a hash.
  repositories = JSON.parse(json)

  ## Extract the array for key 'repositories'.
  repositories = repositories["repositories"]
end

def get_tags(registry_url, repository)
  uri = URI.parse("#{$registry_url}/v2/#{repository}/tags/list")
  http = Net::HTTP.new(uri.host, uri.port, $proxy_addr)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  json = response.body

  ## Convert the json to a hash.
  tags = JSON.parse(json)

  ## Extract the array for key 'tags'.
  tags = tags["tags"]
  tags.delete("latest")

  ## Ensure we're sorting tag version numbers properly.
  begin
    tags = Naturally.sort(tags)
  rescue Exception => e
    puts "ERROR: Could not sort the tags for #{repository}. The most common cause is an inconsistent naming convention."
    puts "       Repository #{repository} will not be pruned."
    puts "       tags = #{tags}"
    $prune_exclude << repository
  end

  ## Return a sorted list of tags, minus 'latest'.
  tags
end

puts "Pruning all but the newest #{$num_tags_to_keep} tags from each repository."

## Retrieve a list of all repos in the docker-registry.
repositories = get_repositories($registry_url)
puts "Found the following repositories on #{$registry_url}"
repositories.each do |r|
  puts "    #{r}"
end

## Start a hash for repositories and tags that need pruning.
$fat_repos = {}

## Determine if any tags need to be deleted.
repositories.each do |repository|
  tags = get_tags($registry_url, repository)
  next if $prune_exclude.include?(repository)
  num_tags = tags.size
  puts "Found #{num_tags} tags in repository #{repository}."
  num_doomed_tags = num_tags - $num_tags_to_keep
  doomed_tags =
    if num_doomed_tags > 0
      tags.take(num_doomed_tags)
    else
      []
    end
  if doomed_tags.size > 0
    puts "Marking the following #{doomed_tags.size} tags for deletion:"
    doomed_tags.each do |t|
      puts "    #{t}"
    end
    $fat_repos["#{repository}"] = doomed_tags
  end
end

## Prune unwanted images.
if !$fat_repos.empty?
  puts "Stopping the docker-registry to avoid race conditions."
  system("/usr/bin/docker stop #{$registry_container_name}")
  $fat_repos.each do |repo, tags|
    tags.each do |tag| 
      puts "Deleting #{repo} image #{tag}"
      begin
        ## --dry-run can be used for testing.
        #system("#{$delete_image_script} --image #{repository}:#{tag} --dry-run")
        system("#{$delete_image_script} --image #{repo}:#{tag}")
      rescue Exception => e
        puts "ERROR: Failed to delete #{repo} image #{tag}" 
      end
    end
  end
  puts "Pruning complete. Starting the docker-registry."
  system("/usr/bin/docker start #{$registry_container_name}")
end

