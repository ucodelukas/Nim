#
#
#                 SSL configuration generator
#     (c) Copyright 2020 Leorize <leorize+oss@disroot.org>
#
#        See the file "copying.txt", included in this
#        distribution, for details about the copyright.
#

import httpclient, json, net, strformat, strutils, sequtils, times

const
  ConfigSource = "https://ssl-config.mozilla.org/guidelines/latest.json"
  OutputFile = "ssl_config.nim"

func appendToList(list, str: string): string =
  if list.len == 0:
    result = str
  elif str.len == 0:
    result = list
  else:
    result = list & ':' & str

proc main() =
  let
    client = newHttpClient(sslContext = newContext(verifyMode = CVerifyPeer))
    resp = client.get(ConfigSource)
  defer: client.close()
  if not resp.code.is2xx:
    quit "Couldn't fetch configuration, server returned: " & $resp.code

  let configs = resp.bodyStream.parseJson("ssl-config.json")

  let generationTime = now().utc()
  let output = open(OutputFile, fmWrite)
  echo "Generating ", OutputFile
  output.writeLine(&"""
# This file was automatically generated by tools/ssl_config_parser on {generationTime}. DO NOT EDIT.

## This module contains SSL configuration parameters obtained from
## `Mozilla OpSec <https://wiki.mozilla.org/Security/Server_Side_TLS>`_.
##
## The configuration file used to generate this module: {configs["href"].getStr}
""")

  for name, config in configs["configurations"]:
    let
      constantName = "Ciphers" & name[0].toUpperAscii & name[1..^1]
      ciphers = config["ciphersuites"].foldl(a.appendToList b.getStr, "").appendToList(
        config["ciphers"]["openssl"].foldl(a.appendToList b.getStr, "")
      )
      oldestClients = config["oldest_clients"].foldl(a & "\n  ## * " & b.getStr, "")

    output.writeLine(&"""
const {constantName}* = "{ciphers}"
  ## An OpenSSL-compatible list of secure ciphers for ``{name}`` compatibility
  ## per Mozilla's recommendations.
  ##
  ## Oldest clients supported by this list:{oldestClients}
""")

when isMainModule: main()
