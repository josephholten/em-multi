## Usage

```bash
docker build -t em-multi .
docker run -d -p 8080:8080 em-multi
firefox -new-tab localhost:8080
# any update on the website (F5) will reproduce the results in the console (Ctrl + Shift + C)
```

***Note**: this starts docker in detached mode. You need to stop it manually. If you didn't run any other docker image, just remove the last one with docker stop $(docker ps -lq).*
