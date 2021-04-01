# cloudflare-api-ddns 
  
说明：该脚本可实现自动更新cloudflare的dns记录，检查频率高达每分钟检查一次 
# 特点： 
     1、公网ip获取方式为从本机执行脚本获取，也就是执行命令的主机是自己拨号并有一个公网ip 
     2、需要用到ifconfig命令，需要安装net-tools这个软件包  
     3、因为用到了source命令，所以需要用bash执行环境，而不是sh  
     
备注： 关于第一点限制说明，执行脚本的主机必须有公网ip，这样就可以不受第三方接口的限制，比如接口频率限制，响应时间不稳定等，直接本机获取公网ip  
  
安装 net-tools  
  
```
apt-get install net-tools 
```

