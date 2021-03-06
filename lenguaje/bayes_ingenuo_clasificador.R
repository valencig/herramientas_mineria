
# Creamos variables con los directorios donde se encuentran los datos
trayectoria_spam     <- file.path("data", "spam_2")
trayectoria_easyham  <- file.path("data", "easy_ham_2")
trayectoria_hardham  <- file.path("data", "hard_ham")

# Leemos el directorio donde se encuentran los correos clasificados como spam
archivos_correos_spam <- dir(trayectoria_spam)

# quitamos el guión llamado cmds
archivos_correos_spam <- archivos_correos_spam[which(archivos_correos_spam!="cmds")] #[1:250]

# hacemos una función que leea el mensaje del archivo que se le pase como parámetro
# asumimos que el archivo contiene un correo

lee_mensaje <- function(correo) {
  fd <- file(correo, open = "rt")
  lineas <- readLines(fd,warn = FALSE)
  close(fd)
  mensaje <- lineas[seq(which(lineas == "")[1] + 1, length(lineas), 1)]
  return (paste(mensaje, collapse = "\n"))
}

todo_spam <- sapply(archivos_correos_spam,
                   function(p) lee_mensaje(file.path(trayectoria_spam, p)))

usePackage <- function(p) 
{
  if (!is.element(p, installed.packages()[,1]))
    install.packages(p, dep = TRUE, repos = "https://cran.itam.mx/")
  require(p, character.only = TRUE)
}

usePackage('tm')

obtiene_TermDocumentMatrix <- function (vector_correos) {
  control <- list(stopwords = TRUE,
                removePunctuation = TRUE,
                removeNumbers = TRUE,
                minDocFreq = 2)
  corpus <- Corpus(VectorSource(vector_correos))
  return(TermDocumentMatrix(corpus, control))
}

todo_spam <- enc2utf8(todo_spam)

spam_TDM <- obtiene_TermDocumentMatrix(todo_spam)

# Crea un data frame que provee el conjunto de caracteristicas de los datos de entrenamiento SPAM
matriz_spam <- as.matrix(spam_TDM)

conteos_spam <- rowSums(matriz_spam)
df_spam <- data.frame(cbind(names(conteos_spam),
                            as.numeric(conteos_spam)),
                      stringsAsFactors = FALSE)
names(df_spam) <- c("terminos", "frecuencia")
df_spam$frecuencia <- as.numeric(df_spam$frecuencia)
ocurrencias_spam <- sapply(1:nrow(matriz_spam),
                          function(i) # Obtiene la proporcion de documentos que contiene cada palabra
                          {
                            length(which(matriz_spam[i, ] > 0)) / ncol(matriz_spam)
                          })
densidad_spam <- df_spam$frecuencia/sum(df_spam$frecuencia,na.rm = TRUE)

df_spam <- transform(df_spam,
                     densidad = densidad_spam,
                     ocurrencias = ocurrencias_spam)


# Leemos el directorio donde se encuentran los correos clasificados como ham fácilmente identificables
archivos_correos_easy_ham <- dir(trayectoria_easyham)

# quitamos el guión llamado cmds
archivos_correos_easy_ham <- archivos_correos_easy_ham[which(archivos_correos_easy_ham!="cmds")] #[1:250]

todo_easy_ham <- sapply(archivos_correos_easy_ham,
                    function(p) lee_mensaje(file.path(trayectoria_easyham, p)))

todo_easy_ham <- enc2utf8(todo_easy_ham)

easy_ham_TDM <- obtiene_TermDocumentMatrix(todo_easy_ham)

# Crea un data frame que provee el conjunto de caracteristicas de los datos de entrenamiento easy ham
matriz_easy_ham <- as.matrix(easy_ham_TDM)

conteos_easy_ham <- rowSums(matriz_easy_ham)
df_easy_ham <- data.frame(cbind(names(conteos_easy_ham),
                            as.numeric(conteos_easy_ham)),
                      stringsAsFactors = FALSE)
names(df_easy_ham) <- c("terminos", "frecuencia")
df_easy_ham$frecuencia <- as.numeric(df_easy_ham$frecuencia)
ocurrencias_easy_ham <- sapply(1:nrow(matriz_easy_ham),
                           function(i) # Obtiene la proporcion de documentos que contiene cada palabra
                           {
                             length(which(matriz_easy_ham[i, ] > 0)) / ncol(matriz_easy_ham)
                           })
densidad_easy_ham <- df_easy_ham$frecuencia/sum(df_easy_ham$frecuencia,na.rm = TRUE)

df_easy_ham <- transform(df_easy_ham,
                     densidad = densidad_easy_ham,
                     ocurrencias = ocurrencias_easy_ham)

clasifica_correo <- function(trayectoria, df_entrenamiento, a_priori = 0.5, c = 1e-6)
{
  mensaje <- lee_mensaje(trayectoria)
  mensaje <- enc2utf8(mensaje)
  mensaje_TDM <- obtiene_TermDocumentMatrix(mensaje)
  conteos_mensaje <- rowSums(as.matrix(mensaje_TDM))

  # Encuentra palabras en data frame de entrenamiento
  mensaje_palabras_comunes <- intersect(names(conteos_mensaje), df_entrenamiento$terminos)
  print(names(mensaje_palabras_comunes)
  # Ahora sólo aplicamos la clasificación Bayes ingenuo
  if(length(mensaje_palabras_comunes) < 1)
  {
    #return(a_priori * c ^ (length(conteos_mensaje)))
    return(log(a_priori) + (length(conteos_mensaje)) *log(c))
  }
  else
  {
    probabilidades_palabras_comunes <- df_entrenamiento$densidad[match(mensaje_palabras_comunes, df_entrenamiento$terminos)]
    #return(a_priori * prod(probabilidades_palabras_comunes) * c ^ (length(conteos_mensaje) - length(mensaje_palabras_comunes)))
    return(log(a_priori) + sum(log(probabilidades_palabras_comunes)) + log(c) * (length(conteos_mensaje) - length(mensaje_palabras_comunes)))
  }
}


# Leemos el directorio donde se encuentran los correos clasificados como ham dificlmente identificables
archivos_correos_hard_ham <- dir(trayectoria_hardham)

# quitamos el guión llamado cmds
archivos_correos_hard_ham <- archivos_correos_hard_ham[which(archivos_correos_hard_ham!="cmds")]

clasifica_spam <- function(trayectoria, archivos) {

  hard_ham_spam_prueba <- sapply(archivos,
                             function(p) clasifica_correo(file.path(trayectoria, p), df_entrenamiento = df_spam))
  hard_ham_ham_prueba <- sapply(archivos,
                            function(p) clasifica_correo(file.path(trayectoria, p), df_entrenamiento = df_easy_ham))
  
  return (ifelse(hard_ham_spam_prueba > hard_ham_ham_prueba,
                        TRUE,
                        FALSE))
}

hard_ham_res <- clasifica_spam(trayectoria_hardham, archivos_correos_hard_ham)
easy_ham_res <- clasifica_spam(trayectoria_easyham, archivos_correos_easy_ham)
spam_res <- clasifica_spam(trayectoria_spam, archivos_correos_spam)

summary(hard_ham_res)
summary(easy_ham_res)
summary(spam_res)

