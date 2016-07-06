Promise = require 'bluebird'
Octokat = require 'octokat'
request = require 'request-promise'
{log} = require 'lightsaber'
{merge, round, sample, size, sortBy} = require 'lodash'
Wave = require 'loading-wave'
$ = require 'jquery'
require('datatables.net')()
require('datatables.net-fixedheader')()
{
  a
  div
  img
  raw
  render
  renderable
  span
  table
  tbody
  td
  th
  thead
  tr
} = require 'teacup'

ORG = 'ipfs'

RAW_GITHUB_SOURCES = [
  (repoName, path) -> "https://raw.githubusercontent.com/#{ORG}/#{repoName}/master/#{path}"
  # (repoName, path) -> "https://rawgit.com/#{ORG}/#{repoName}/master/#{path}"
  # (repoName, path) -> "https://raw.githack.com/#{ORG}/#{repoName}/master/#{path}"  # funky error messages on 404
]

README_BADGES =
  'Travis': (repoName) -> "](https://travis-ci.org/#{ORG}/#{repoName}.svg?branch=master)](https://travis-ci.org/#{ORG}/#{repoName})"
  'Circle': (repoName) -> "](https://circleci.com/gh/#{ORG}/#{repoName}.svg?style=svg)](https://circleci.com/gh/#{ORG}/#{repoName})"
  'Made By': -> '[![](https://img.shields.io/badge/made%20by-Protocol%20Labs-blue.svg?style=flat-square)](http://ipn.io)'
  'Project': -> '[![](https://img.shields.io/badge/project-IPFS-blue.svg?style=flat-square)](http://ipfs.io/)'
  'IRC':     -> '[![](https://img.shields.io/badge/freenode-%23ipfs-blue.svg?style=flat-square)](http://webchat.freenode.net/?channels=%23ipfs)'

README_OTHER =
  'Banner': -> '![](https://cdn.rawgit.com/jbenet/contribute-ipfs-gif/master/img/contribute.gif)'

README_ITEMS = merge README_BADGES, README_OTHER

github = new Octokat

main = ->
  @wave = loadingWave()
  loadRepos()
  .catch (err) ->
    console.log('err', err)
    killLoadingWave @wave
    errMsg = 'Unable to access GitHub. <a href="https://twitter.com/githubstatus">Is it down?</a>'
    $(document.body).append(errMsg)
    throw new Error('Unable to access api.github.com')
  .then (@repos) => killLoadingWave @wave
  .then => showMatrix @repos
  .then => loadStats()

loadingWave = ->
  wave = Wave
    width: 162
    height: 62
    n: 7
    color: '#959'
  $(wave.el).center()
  document.body.appendChild wave.el
  wave.start()
  wave

killLoadingWave = (wave) ->
  wave.stop()
  $(wave.el).hide()

loadRepos = ->
  github.orgs('ipfs').repos.fetch(per_page: 100)
  .then (repos) -> getReadmes repos

showMatrix = (repos) ->
  $('#matrix').append matrix repos
  $('table').DataTable
    paging: false
    searching: false
    fixedHeader: true

getReadmes = (repos) ->
  repos = sortBy repos, 'name'
  Promise.map repos, (repo) ->
    uri = sample(RAW_GITHUB_SOURCES)(repo.name, 'README.md')
    request {uri}
    .then (readmeText) ->
      repo.readmeText = readmeText
      repo
    .then (repo) ->
      uri = sample(RAW_GITHUB_SOURCES)(repo.name, 'LICENSE')
      request {uri}
      .then (license) -> repo.license = (license)
      .then (repo) ->
        uri = sample(RAW_GITHUB_SOURCES)(repo.name, 'PATENTS')
        request {uri}
        .then (patents) -> repo.patents = (patents)
        .then (repo) ->
          uri = sample(RAW_GITHUB_SOURCES)(repo.name, 'CONTRIBUTE.md')
          request {uri}
          .then (contribute) -> repo.contribute = (contribute)
    .error (err) -> console.error [".error:", uri, err].join("\n")
    .catch (err) -> console.error [".catch:", uri, err].join("\n")
  .then -> repos

matrix = renderable (repos) ->
  table class: 'stripe order-column compact cell-border', ->
    thead ->
      tr ->
        th ->
        th colspan: 2, -> "Builds"
        th colspan: 2, -> "README.md"
        th colspan: 2, -> "Files"
        th colspan: size(README_ITEMS), -> "Badges"
      tr ->
        th class: 'left', -> "IPFS Repo"
        th class: 'left', -> "Travis CI"
        th class: 'left', -> "Circle CI"
        th -> "exists"
        th -> "> 500 chars"
        th -> "license"
        th -> "patents"
        th -> "contribute"
        for name of README_ITEMS
          th -> name
    tbody ->
      for repo in repos
        console.log(repo)
        tr ->
          td class: 'left', ->
            a href: "https://github.com/#{ORG}/#{repo.name}", -> repo.name
          td class: 'left', -> travis repo.name
          td class: 'left', -> circle repo.name
          td class: 'no-padding', -> check repo.readmeText?
          td class: 'no-padding', -> check(repo.readmeText? and repo.readmeText.length > 500)
          td class: 'no-padding', -> check repo.license
          td class: 'no-padding', -> check repo.patents
          td class: 'no-padding', -> check repo.contribute
          for name, template of README_ITEMS
            expectedMarkdown = template repo.name
            td class: 'no-padding', -> check (repo.readmeText? and repo.readmeText?.indexOf(expectedMarkdown) isnt -1)

check = renderable (success) ->
  if success
    div class: 'success', -> '✓'
  else
    div class: 'failure', -> '✗'

travis = renderable (repoName) ->
  a href: "https://travis-ci.org/#{ORG}/#{repoName}", ->
    img src: "https://travis-ci.org/#{ORG}/#{repoName}.svg?branch=master"

circle = renderable (repoName) ->
  a href: "https://circleci.com/gh/#{ORG}/#{repoName}", ->
    img src: "https://circleci.com/gh/#{ORG}/#{repoName}.svg?style=svg", onError: "this.src = 'images/circle-ci-no-builds.svg'"

loadStats = ->
  github.rateLimit.fetch()
  .then (info) -> $('#stats').append stats info

stats = renderable (info) ->
  {resources: {core: {limit, remaining, reset}}} = info
  div class: 'stats', ->
    now = (new Date).getTime() / 1000  # seconds
    minutesUntilReset = (reset - now) / 60     # minutes
    "Github API calls: #{remaining} remaining of #{limit} limit per hour; clean slate in: #{round minutesUntilReset, 1} minutes"

$.fn.center = ->
  @css 'position', 'absolute'
  @css 'top', Math.max(0, ($(window).height() - $(this).outerHeight()) / 2 + $(window).scrollTop()) + 'px'
  @css 'left', Math.max(0, ($(window).width() - $(this).outerWidth()) / 2 + $(window).scrollLeft()) + 'px'
  @

main()
