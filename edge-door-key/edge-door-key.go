package main

import (
  "fmt"
  "os"
  "log"
  "strings"
  "io/ioutil"
  "net/http"
  "gopkg.in/yaml.v2"
  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/aws/session"
  "github.com/aws/aws-sdk-go/aws/credentials"
  "github.com/aws/aws-sdk-go/aws/awserr"
  "github.com/aws/aws-sdk-go/service/s3"
  "github.com/aws/aws-sdk-go/service/s3/s3manager"
)

type conf struct {
    UserName string `yaml:"user_name"`
    AccessKey string `yaml:"aws_access_key"`
    SecretKey string `yaml:"aws_secret_key"`
    Bucket string `yaml:"aws_s3_bucket"`
    Region string `yaml:"aws_region"`
}

const configfile string = "edge-door-key.yml"

func (c *conf) getConf() *conf {
    dirname, err := os.UserHomeDir()
    if err != nil {
        log.Fatal( err )
    }
    yamlFile, err := ioutil.ReadFile(dirname + "/.config/" + configfile)
    if err != nil {
        log.Fatal("yamlFile.Get err   #%v ", err)
    }
    err = yaml.Unmarshal(yamlFile, c)
    if err != nil {
        log.Fatal("Unmarshal: %v", err)
    }
    return c
}

func usage() {
  fmt.Fprintf(os.Stderr, "Usage: %s <open|open4|open6|close>\n", os.Args[0])
  os.Exit(2)
}

func getIP4() string {
  res, err := http.Get("https://api4.ipify.org")
  if err != nil {
    return ""
  }
  ip, _ := ioutil.ReadAll(res.Body)
  return string(ip)
}

func getIP6() string {
  res, err := http.Get("https://api6.ipify.org")
  if err != nil {
    return ""
  }
  ip, _ := ioutil.ReadAll(res.Body)
  return string(ip)
}

func initAWS(c conf) *session.Session {
  // set up AWS session
  creds := credentials.NewStaticCredentials(c.AccessKey, c.SecretKey, "")
  sess := session.New(&aws.Config{
    Credentials: creds,
    Region: aws.String(c.Region),
  })
  return sess
}

func dropKey(c conf, key string) {
  sess := initAWS(c)
  svc := s3.New(sess)
  input := &s3.DeleteObjectsInput{
    Bucket: aws.String(c.Bucket),
    Delete: &s3.Delete{
      Objects: []*s3.ObjectIdentifier{
	{
          Key: aws.String(key),
        },
      },
      Quiet: aws.Bool(true),
    },
  }
  // real delete api call
  _, err := svc.DeleteObjects(input)
  if err != nil {
    if aerr, ok := err.(awserr.Error); ok {
      switch aerr.Code() {
        default:
          log.Fatal(aerr.Error())
      }
    } else {
      // Print the error, cast err to awserr.Error to get the Code and
      // Message from an error.
      log.Fatal(err.Error())
    }
    os.Exit(1)
  }
}

func doorOpen(c conf, v4 bool, v6 bool) {
  sess := initAWS(c)
  var myip4 string = ""
  var myip6 string = ""
  if v4 {
    myip4 = getIP4()
  }
  if v6 {
    myip6 = getIP6()
  }
  uploader := s3manager.NewUploader(sess)
  // IPv4
  if len(myip4) > 0 {
    uploader.Upload(&s3manager.UploadInput{
      ACL: aws.String("private"),
      Bucket: aws.String(c.Bucket),
      Key: aws.String("ipv4/"+c.UserName),
      ContentType: aws.String("text/plain"),
      Body: strings.NewReader(myip4),
    })
    fmt.Println(os.Args[0] + ": door opened for "+c.UserName+"@" + myip4)
  } else {
    dropKey(c, "ipv4/"+c.UserName)
  }
  // IPv6
  if len(myip6) > 0 {
    uploader.Upload(&s3manager.UploadInput{
      ACL: aws.String("private"),
      Bucket: aws.String(c.Bucket),
      Key: aws.String("ipv6/"+c.UserName),
      ContentType: aws.String("text/plain"),
      Body: strings.NewReader(myip6),
    })
    fmt.Println(os.Args[0] + ": door opened for "+c.UserName+"@" + myip6)
  } else {
    dropKey(c, "ipv6/"+c.UserName)
  }
}

func doorClose(c conf) {
  dropKey(c, "ipv4/"+c.UserName)
  dropKey(c, "ipv6/"+c.UserName)
  fmt.Println(os.Args[0] + ": door closed for " + c.UserName)
}

func main() {
  // load config
  var c conf
  c.getConf()
  // do the job
  if (len(os.Args) == 2 && os.Args[1] == "open") {
    // open
    doorOpen(c, true, true)
  } else if (len(os.Args) == 2 && os.Args[1] == "open4") {
    doorOpen(c, true, false)
  } else if (len(os.Args) == 2 && os.Args[1] == "open6") {
    doorOpen(c, false, true)
  } else if (len(os.Args) == 2 && os.Args[1] == "close") {
    // close
    doorClose(c)
  } else {
    // wrong invocation
    usage()
  }
}
