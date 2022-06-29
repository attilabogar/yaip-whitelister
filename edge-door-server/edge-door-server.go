package main

import (
  "log"
  "strings"
  "os"
  "os/exec"
  "io/ioutil"
  "net/http"
  "text/template"
  "gopkg.in/yaml.v2"
)

type conf struct {
    IP4Url string `yaml:"ipv4_url"`
    IP6Url string `yaml:"ipv6_url"`
    Templates []string `yaml:"templates"`
}

const f_etag4 = "/tmp/ipv4.cache"
const f_etag6 = "/tmp/ipv6.cache"
const f_shell = "/tmp/edge-door-server-apply.sh"
const f_cfg = "./edge-door-server.yml"

var client http.Client

func (c *conf) getConf() *conf {
    yamlFile, err := ioutil.ReadFile(f_cfg)
    if err != nil {
        log.Printf("yamlFile.Get err   #%v ", err)
    }
    err = yaml.Unmarshal(yamlFile, c)
    if err != nil {
        log.Fatalf("Unmarshal: %v", err)
    }
    return c
}

func getETagCached(name string) string {
  if _, err := os.Stat(name); os.IsNotExist(err) {
    return ""
  }

  // there is a cached etag
  f, err := os.Open(name)
  if err != nil {
    panic(err)
  }
  buf := make([]byte, 32)
  ntag, err := f.Read(buf)
  if ntag == 32 {
    // as expected
    return string(buf)
  }
  return ""
}

func getETagLive(ip_url string) string {
  resp, err := client.Head(ip_url)
    if err != nil {
    panic(err)
  }

  if resp.StatusCode == 200 {
    head := resp.Header
    etag := strings.Trim(head.Get("ETag"), "\"")
    return etag
  }

  return ""
}

func setETagCache(name string, etag string) {
  err := ioutil.WriteFile(name, []byte(etag), 0644)
  if err != nil {
    panic(err)
  }
}

func getIPList(ip_url string) []string {
  resp, err := client.Get(ip_url)
  if err != nil {
    panic(err)
  }
  defer resp.Body.Close()

  var ret []string
  if resp.StatusCode == 200 {
    body, err := ioutil.ReadAll(resp.Body)
    if err == nil {
      // get the correct IPv4 addresses only
      tmplist := strings.Split(string(body), "\n")
      var iplist []string
      if len(tmplist)>0 {
        iplist = tmplist[:len(tmplist)-1]
      }
      return iplist
    }
  }
  return ret
}

func genTemplate(iplist4 []string, iplist6 []string, tf string) {
  type ShellScript struct {
    IPList4 []string
    IPList6 []string
  }

  // log.Println("TF="+tf)
  val := ShellScript{iplist4, iplist6}
  tmpl, err := template.New("").ParseFiles(tf)
  if err != nil { panic(err) }

  // create output file
  f, err := os.Create(f_shell)
  err = tmpl.ExecuteTemplate(f, tf, val)
  f.Close()
  if err != nil { os.Remove(f_shell); panic(err) }
  err = os.Chmod(f_shell, 0755)
  if err != nil { os.Remove(f_shell); panic(err) }
}

func applyTemplate() {
  // we assume f_shell exists at this point
  cmd := exec.Command("/bin/bash", f_shell)
  err := cmd.Run()
  if err != nil { os.Remove(f_shell); panic(err) }
  os.Remove(f_shell)
}

func main() {
  // check for LOCK
  if _, err := os.Stat(f_shell); !os.IsNotExist(err) {
    log.Println("LOCKED")
    os.Exit(0)
  }

  // parse config
  var c conf
  c.getConf()

  // get live ETag
  etagLive4 := getETagLive(c.IP4Url)
  etagLive6 := getETagLive(c.IP6Url)

  // get cached ETag
  etagCached4 := getETagCached(f_etag4)
  etagCached6 := getETagCached(f_etag6)

  // DEBUG
  // log.Println("LIVE: " + etagLive)
  // log.Println("CACHED: " + etagCached)

  if etagLive4 != etagCached4 || etagLive6 != etagCached6 {
    // apply changes to router
    var iplist4 []string
    var iplist6 []string
    iplist4 = getIPList(c.IP4Url)
    iplist6 = getIPList(c.IP6Url)
    log.Println(iplist4)
    log.Println(iplist6)
    // generate templates
    for i := 0; i < len(c.Templates); i++ {
      genTemplate(iplist4, iplist6, c.Templates[i])
      applyTemplate()
    }
    setETagCache(f_etag4, etagLive4)
    setETagCache(f_etag6, etagLive6)
  } else {
    log.Println("IDLE")
  }
}
