# saas
https://blog.katastros.com/a?ID=01600-cdd358aa-fba2-4b4c-9448-7cb34797482c
1 Overview
The author has been in contact with SaaS (Software as a Service), a multi-tenant (or multi-tenant) software application platform since 2014; and has been engaged in architecture design and research and development in related fields. By chance, when the author completed his undergraduate graduation project, he completed a project research on an efficient SaaS-based financial management platform, and gained a lot from it. When I first came into contact with SaaS, domestic related resources were scarce. The only reference material I had was the book "Software Revolution in the Internet Era: SaaS Architecture Design" (by Ye Wei et al.). The realization of the final subject is based on the OSGI (Open Service Gateway Initiative) Java dynamic modular system specification.

Today, five years have passed. The technology of software development has undergone tremendous changes. The technology stack of the SaaS platform that the author has implemented has also been updated several waves, which really confirms the words: "The mountains and rivers have no way out. There is another village in the dark." Based on the many detours and pits I have traveled before, and recently many netizens have asked me how to use Spring Boot to implement a multi-tenant system, and decided to write an article to talk about the hard-core technology of SaaS.

Speaking of SaaS, it is just a software architecture, there are not many mysterious things, and it is not a difficult system. My personal feeling is that the difficulty of the SaaS platform lies in the commercial operation, not the technical realization. Technically speaking, SaaS is an architectural model: it allows users in multiple different environments to use the same set of applications, and ensures that the data between users is isolated from each other. Thinking about it now, this is also a bit of a sharing economy.

The author will not discuss in depth the comparison between SaaS software maturity model and data isolation solution here. Today I want to talk about using Spring Boot to quickly build a multi-tenant system with independent database/shared database independent Schema. I will provide a core technical implementation of the SaaS system, and other interested friends can expand on this basis.

2. Try to understand the application scenarios of multi-tenancy
Suppose we need to develop an application and hope to sell the same application to N customers. Under normal circumstances, we need to create N web servers (Tomcat), N databases (DB), and deploy the same application N times for N customers. Now, if our application is upgraded or made any other changes, then we need to update N applications and also need to maintain N servers. Next, if the business starts to grow and the number of customers changes from the original N to the current N+M, we will face the issues of N applications and M application version maintenance, equipment maintenance and cost control. O&M is almost crying to death in the computer room...

In order to solve the above problems, we can develop multi-tenant applications. We can choose the corresponding database according to who the current user is. For example, when requesting a user from company A, the application connects to the database of company A, and when requesting a user from company B, the database is automatically switched to the database of company B, and so on. In theory, there will be no problem, but if we consider transforming the existing application into a SaaS model, we will encounter the first problem: How to identify which tenant the request comes from? How to automatically switch data sources?

3. Maintain, identify and route tenant data sources
We can provide an independent library to store tenant information, such as database name, link address, user name, password, etc., which can uniformly solve the problem of tenant information maintenance. There are many ways to identify and route tenants. Here are a few common ways:

1. Tenants can be identified by domain name: we can provide each tenant with a unique second-level domain name, and the ability to identify tenants can be achieved through the second-level domain name, such as tenant.example.com, tenant.example.com; Tenantone and tenant are our key information to identify tenants.
2. The tenant information can be passed to the server as request parameters to provide support for the server to identify tenants, such as saas.example.com?tenantId=tenant1,saas.example.com?tenantId=tenant2. The parameter tenantId is the key information for the application to identify the tenant.
3. The tenant information can be set in the request header (Header), such as JWT and other technologies, and the server obtains the tenant information by parsing the relevant parameters in the Header.
4. After the user successfully logs in to the system, save the tenant information in the Session, and retrieve the tenant information from the Session when needed. After solving the above problems, let's take a look at how to obtain the tenant information passed in by the client and how to use the tenant information in our business code (the most important thing is the problem of DataSources).
We all know that before starting a Spring Boot application, we need to provide it with configuration information about the data source (if the database is used). According to the initial needs, there are N customers who need to use our application. We need to configure N data sources (multiple data sources) in advance. If N<50, I think I can tolerate it. If there are more, this is obviously unacceptable. In order to solve this problem, we need to use the dynamic data source feature provided by Hibernate 5, so that our application has the ability to dynamically configure the client data source. Simply put, when a user requests system resources, we store the tenant information (tenantId) provided by the user in ThreadLoacal, and then obtain the tenant information in TheadLocal, and query a separate tenant database based on this information to obtain the data of the current tenant Configure the information, and then use the ability of Hibernate to dynamically configure the data source to set the data source for the current request, and finally the previous user's request. In this way, we only need to maintain a copy of the data source configuration information (tenant database configuration library) in the application, and dynamically query the configuration for the remaining data sources. Next, we will quickly demonstrate this feature.

4. Project Construction
We will use Spring Boot 2.1.5 to implement this demo project. 1. you need to add the following configuration to the Maven configuration file:

<dependencies>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter</artifactId>
		</dependency>

		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-devtools</artifactId>
			<scope>runtime</scope>
		</dependency>
		<dependency>
			<groupId>org.projectlombok</groupId>
			<artifactId>lombok</artifactId>
			<optional>true</optional>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-test</artifactId>
			<scope>test</scope>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-data-jpa</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-web</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-configuration-processor</artifactId>
		</dependency>
		<dependency>
			<groupId>mysql</groupId>
			<artifactId>mysql-connector-java</artifactId>
			<version>5.1.47</version>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-freemarker</artifactId>
		</dependency>
		<dependency>
			<groupId>org.apache.commons</groupId>
			<artifactId>commons-lang3</artifactId>
		</dependency>
	</dependencies>
	
Then provide a usable configuration file and add the following content:

spring:
  freemarker:
    cache: false
    template-loader-path:
    - classpath:/templates/
    prefix:
    suffix: .html
  resources:
    static-locations:
    - classpath:/static/
  devtools:
    restart:
      enabled: true
  jpa:
    database: mysql
    show-sql: true
    generate-ddl: false
    hibernate:
      ddl-auto: none
una:
  master:
    datasource:
      url:  jdbc:mysql://localhost:3306/master_tenant?useSSL=false
      username: root
      password: root
      driverClassName:  com.mysql.jdbc.Driver
      maxPoolSize:  10
      idleTimeout:  300000
      minIdle:  10
      poolName: master-database-connection-pool
logging:
  level:
    root: warn
    org:
      springframework:
        web:  debug
      hibernate: debug
Since Freemarker is used as the view rendering engine, it is necessary to provide Freemarker's related technology una:master:datasource configuration item is the data source configuration information that uniformly stores tenant information as mentioned above. You can understand it as the main library.

Next, we need to turn off the automatic configuration data source function of Spring Boot, and add the following settings to the project main class:

@SpringBootApplication(exclude = {DataSourceAutoConfiguration.class})
public class UnaSaasApplication {

	public static void main(String[] args) {
		SpringApplication.run(UnaSaasApplication.class, args);
	}

}
Finally, let us look at the structure of the entire project:


5. Implement the tenant data source query module
We will define an entity class to store tenant data source information, which contains information such as tenant name, database connection address, user name and password, and the code is as follows:

@Data
@Entity
@Table(name = "MASTER_TENANT")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MasterTenant implements Serializable{

    @Id
    @Column(name="ID")
    private String id;

    @Column(name = "TENANT")
    @NotEmpty(message = "Tenant identifier must be provided")
    private String tenant;

    @Column(name = "URL")
    @Size(max = 256)
    @NotEmpty(message = "Tenant jdbc url must be provided")
    private String url;

    @Column(name = "USERNAME")
    @Size(min = 4,max = 30,message = "db username length must between 4 and 30")
    @NotEmpty(message = "Tenant db username must be provided")
    private String username;

    @Column(name = "PASSWORD")
    @Size(min = 4,max = 30)
    @NotEmpty(message = "Tenant db password must be provided")
    private String password;

    @Version
    private int version = 0;
}

In the persistence layer, we will inherit the JpaRepository interface to quickly implement the CURD operation on the data source. At the same time, we will provide an interface for finding the data source of the tenant by the tenant name. The code is as follows:

package com.ramostear.una.saas.master.repository;

import com.ramostear.una.saas.master.model.MasterTenant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/**
 * @author : Created by Tan Chaohong (alias:ramostear)
 * @create-time 2019/5/25 0025-8:22
 * @modify by :
 * @since:
 */
@Repository
public interface MasterTenantRepository extends JpaRepository<MasterTenant,String>{

    @Query("select p from MasterTenant p where p.tenant = :tenant")
    MasterTenant findByTenant(@Param("tenant") String tenant);
}
The business layer provides services for obtaining tenant data source information by tenant name (you can add other services by yourself):

package com.ramostear.una.saas.master.service;

import com.ramostear.una.saas.master.model.MasterTenant;

/**
 * @author : Created by Tan Chaohong (alias:ramostear)
 * @create-time 2019/5/25 0025-8:26
 * @modify by :
 * @since:
 */

public interface MasterTenantService {
   /**
     * Using custom tenant name query
     * @param tenant    tenant name
     * @return          masterTenant
     */
    MasterTenant findByTenant(String tenant);
}

Finally, we need to focus on configuring the main data source (Spring Boot needs to provide a default data source for it). Before configuration, we need to obtain configuration items, which can be obtained through @ConfigurationProperties("una.master.datasource") to obtain the relevant configuration information in the configuration file:

@Getter
@Setter
@Configuration
@ConfigurationProperties("una.master.datasource")
public class MasterDatabaseProperties {

    private String url;

    private String password;

    private String username;

    private String driverClassName;

    private long connectionTimeout;

    private int maxPoolSize;

    private long idleTimeout;

    private int minIdle;

    private String poolName;

    @Override
    public String toString(){
        StringBuilder builder = new StringBuilder();
        builder.append("MasterDatabaseProperties [ url=")
                .append(url)
                .append(", username=")
                .append(username)
                .append(", password=")
				.append(password)
                .append(", driverClassName=")
                .append(driverClassName)
                .append(", connectionTimeout=")
                .append(connectionTimeout)
                .append(", maxPoolSize=")
                .append(maxPoolSize)
                .append(", idleTimeout=")
                .append(idleTimeout)
                .append(", minIdle=")
                .append(minIdle)
                .append(", poolName=")
                .append(poolName)
                .append("]");
        return builder.toString();
    }
}

Next is to configure a custom data source, the source code is as follows:

package com.ramostear.una.saas.master.config;

import com.ramostear.una.saas.master.config.properties.MasterDatabaseProperties;
import com.ramostear.una.saas.master.model.MasterTenant;
import com.ramostear.una.saas.master.repository.MasterTenantRepository;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.hibernate.cfg.Environment;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.dao.annotation.PersistenceExceptionTranslationPostProcessor;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.JpaVendorAdapter;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import javax.persistence.EntityManagerFactory;
import javax.sql.DataSource;
import java.util.Properties;

/**
 * @author : Created by Tan Chaohong (alias:ramostear)
 * @create-time 2019/5/25 0025-8:31
 * @modify by :
 * @since:
 */
@Configuration
@EnableTransactionManagement
@EnableJpaRepositories(basePackages = {"com.ramostear.una.saas.master.model","com.ramostear.una.saas.master.repository"},
                       entityManagerFactoryRef = "masterEntityManagerFactory",
                       transactionManagerRef = "masterTransactionManager")
@Slf4j
public class MasterDatabaseConfig {

    @Autowired
    private MasterDatabaseProperties masterDatabaseProperties;

    @Bean(name = "masterDatasource")
    public DataSource masterDatasource(){
        log.info("Setting up masterDatasource with :{}",masterDatabaseProperties.toString());
        HikariDataSource datasource = new HikariDataSource();
        datasource.setUsername(masterDatabaseProperties.getUsername());
        datasource.setPassword(masterDatabaseProperties.getPassword());
        datasource.setJdbcUrl(masterDatabaseProperties.getUrl());
        datasource.setDriverClassName(masterDatabaseProperties.getDriverClassName());
		datasource.setPoolName(masterDatabaseProperties.getPoolName());
        datasource.setMaximumPoolSize(masterDatabaseProperties.getMaxPoolSize());
        datasource.setMinimumIdle(masterDatabaseProperties.getMinIdle());
        datasource.setConnectionTimeout(masterDatabaseProperties.getConnectionTimeout());
        datasource.setIdleTimeout(masterDatabaseProperties.getIdleTimeout());
        log.info("Setup of masterDatasource successfully.");
        return datasource;
    }
	@Primary
    @Bean(name = "masterEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean masterEntityManagerFactory(){
        LocalContainerEntityManagerFactoryBean lb = new LocalContainerEntityManagerFactoryBean();
        lb.setDataSource(masterDatasource());
        lb.setPackagesToScan(
           new String[]{MasterTenant.class.getPackage().getName(), MasterTenantRepository.class.getPackage().getName()}
        );

       //Setting a name for the persistence unit as Spring sets it as 'default' if not defined.
        lb.setPersistenceUnitName("master-database-persistence-unit");

       //Setting Hibernate as the JPA provider.
        JpaVendorAdapter vendorAdapter = new HibernateJpaVendorAdapter();
        lb.setJpaVendorAdapter(vendorAdapter);

       //Setting the hibernate properties
        lb.setJpaProperties(hibernateProperties());

        log.info("Setup of masterEntityManagerFactory successfully.");
        return lb;
    }
	@Bean(name = "masterTransactionManager")
    public JpaTransactionManager masterTransactionManager(@Qualifier("masterEntityManagerFactory")EntityManagerFactory emf){
        JpaTransactionManager transactionManager = new JpaTransactionManager();
        transactionManager.setEntityManagerFactory(emf);
        log.info("Setup of masterTransactionManager successfully.");
        return transactionManager;
    }

    @Bean
    public PersistenceExceptionTranslationPostProcessor exceptionTranslationPostProcessor(){
        return new PersistenceExceptionTranslationPostProcessor();
    }
	private Properties hibernateProperties(){
        Properties properties = new Properties();
        properties.put(Environment.DIALECT,"org.hibernate.dialect.MySQL5Dialect");
        properties.put(Environment.SHOW_SQL,true);
        properties.put(Environment.FORMAT_SQL,true);
        properties.put(Environment.HBM2DDL_AUTO,"update");
        return properties;
    }
}
In the modification configuration category, we mainly provide the configuration of package scanning path, entity management project, transaction manager and data source configuration parameters.

6. Implement tenant business module
In this section, we only provide a user login scenario to demonstrate the functions of SaaS in the tenant business module. The entity layer, business layer and persistence layer are the same as ordinary Spring Boot Web projects, and you don't even feel that it is the code of a SaaS application.

1. create a user entity User whose source code is as follows:

@Entity
@Table(name = "USER")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User implements Serializable {
    private static final long serialVersionUID = -156890917814957041L;

    @Id
    @Column(name = "ID")
    private String id;

    @Column(name = "USERNAME")
    private String username;

    @Column(name = "PASSWORD")
    @Size(min = 6,max = 22,message = "User password must be provided and length between 6 and 22.")
    private String password;

    @Column(name = "TENANT")
    private String tenant;
}
The business layer provides a service for retrieving user information based on the user name. It will call the persistence layer to retrieve the tenant’s user table based on the user name. If it finds a user record that meets the conditions, it will return the user information. If it is not found, then Return null; the source code of the persistence layer and business layer are as follows:

@Repository
public interface UserRepository extends JpaRepository<User,String>,JpaSpecificationExecutor<User>{

    User findByUsername(String username);
}
@Service("userService")
public class UserServiceImpl implements UserService{

    @Autowired
    private UserRepository userRepository;

    private static TwitterIdentifier identifier = new TwitterIdentifier();



    @Override
    public void save(User user) {
        user.setId(identifier.generalIdentifier());
        user.setTenant(TenantContextHolder.getTenant());
        userRepository.save(user);
    }

    @Override
    public User findById(String userId) {
        Optional<User> optional = userRepository.findById(userId);
        if(optional.isPresent()){
            return optional.get();
        }else{
            return null;
        }
    }

    @Override
    public User findByUsername(String username) {
        System.out.println(TenantContextHolder.getTenant());
        return userRepository.findByUsername(username);
    }
Here, we use Twitter's snowflake algorithm to implement an ID generator.

7. Configure the interceptor
We need to provide a tenant information interceptor to obtain the tenant identifier. The source code and configuration interceptor source code are as follows:

/**
 * @author : Created by Tan Chaohong (alias:ramostear)
 * @create-time 2019/5/26 0026-23:17
 * @modify by :
 * @since:
 */
@Slf4j
public class TenantInterceptor implements HandlerInterceptor{

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        String tenant = request.getParameter("tenant");
        if(StringUtils.isBlank(tenant)){
            response.sendRedirect("/login.html");
            return false;
        }else{
            TenantContextHolder.setTenant(tenant);
            return true;
        }
    }
}
@Configuration
public class InterceptorConfig extends WebMvcConfigurationSupport {

    @Override
    protected void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new TenantInterceptor()).addPathPatterns("/**").excludePathPatterns("/login.html");
        super.addInterceptors(registry);
    }
}
/login.html is the login path of the system, we need to exclude it from the interception scope, otherwise we will never be able to log in

8. Maintain tenant identification information
Here, we use ThreadLocal to store tenant identification information and provide data support for dynamically setting data sources. This class provides three static methods: setting tenant identification, obtaining tenant identification, and clearing tenant identification. The source code is as follows:

public class TenantContextHolder {

    private static final ThreadLocal<String> CONTEXT = new ThreadLocal<>();

    public static void setTenant(String tenant){
        CONTEXT.set(tenant);
    }

    public static String getTenant(){
        return CONTEXT.get();
    }

    public static void clear(){
        CONTEXT.remove();
    }
}

The key to dynamic data source settings

9. Dynamic data source switching
To achieve dynamic data source switching, we need to use two classes to complete, CurrentTenantIdentifierResolver and AbstractDataSourceBasedMultiTenantConnectionProviderImpl. It can be seen from their naming that one is responsible for parsing the tenant ID, and the other is responsible for providing tenant data source information corresponding to the tenant ID. 1. we need to implement the resolveCurrentTenantIdentifier() and validateExistingCurrentSessions() methods in the CurrentTenantIdentifierResolver interface to complete the tenant identification resolution function. The source code of the implementation class is as follows:

package com.ramostear.una.saas.tenant.config;

import com.ramostear.una.saas.context.TenantContextHolder;
import org.apache.commons.lang3.StringUtils;
import org.hibernate.context.spi.CurrentTenantIdentifierResolver;

/**
 * @author: Created by Tan Chaohong (alias:ramostear)
 * @create-time 2019/5/26 0026-22:38
 * @modify by:
 * @since:
 */
 public class CurrentTenantIdentifierResolverImpl implements CurrentTenantIdentifierResolver {

   /**
     * Default tenant ID
     */
    private static final String DEFAULT_TENANT = "tenant_1";

   /**
     * Parse the ID of the current tenant
     * @return
     */
    @Override
    public String resolveCurrentTenantIdentifier() {
       //Obtain the tenant ID through the tenant context, which is set in the header when the user logs in
        String tenant = TenantContextHolder.getTenant();
       //If the tenant ID is not found in the context, use the default tenant ID, or report exception information directly
        return StringUtils.isNotBlank(tenant)?tenant:DEFAULT_TENANT;
    }

    @Override
    public boolean validateExistingCurrentSessions() {
        return true;
    }
}
The logic of this class is very simple, that is, obtain the currently set tenant identifier from ThreadLocal

With the tenant identifier parsing class, we need to extend the tenant data source providing class to dynamically query the tenant data source information from the database. The source code is as follows:

@Slf4j
@Configuration
public class DataSourceBasedMultiTenantConnectionProviderImpl extends AbstractDataSourceBasedMultiTenantConnectionProviderImpl{

    private static final long serialVersionUID = -7522287771874314380L;
	@Autowired
    private MasterTenantRepository masterTenantRepository;

    private Map<String,DataSource> dataSources = new TreeMap<>();

    @Override
    protected DataSource selectAnyDataSource() {
        if(dataSources.isEmpty()){
            List<MasterTenant> tenants = masterTenantRepository.findAll();
            tenants.forEach(masterTenant->{
                dataSources.put(masterTenant.getTenant(), DataSourceUtils.wrapperDataSource(masterTenant));
            });
        }
        return dataSources.values().iterator().next();
    }
@Override
    protected DataSource selectDataSource(String tenant) {
        if(!dataSources.containsKey(tenant)){
            List<MasterTenant> tenants = masterTenantRepository.findAll();
            tenants.forEach(masterTenant->{
                dataSources.put(masterTenant.getTenant(),DataSourceUtils.wrapperDataSource(masterTenant));
            });
        }
        return dataSources.get(tenant);
    }
}

In this category, the tenant data source information is dynamically obtained by querying the tenant data source library, and data data support is provided for the data source configuration of the tenant business module.

Finally, we also need to provide the tenant business module data source configuration, which is the core of the entire project. The code is as follows:

@Slf4j
@Configuration
@EnableTransactionManagement
@ComponentScan(basePackages = {
        "com.ramostear.una.saas.tenant.model",
        "com.ramostear.una.saas.tenant.repository"
})
@EnableJpaRepositories(basePackages = {
        "com.ramostear.una.saas.tenant.repository",
        "com.ramostear.una.saas.tenant.service"
},entityManagerFactoryRef = "tenantEntityManagerFactory"
,transactionManagerRef = "tenantTransactionManager")
public class TenantDataSourceConfig {

    @Bean("jpaVendorAdapter")
    public JpaVendorAdapter jpaVendorAdapter(){
        return new HibernateJpaVendorAdapter();
    }
	 @Bean(name = "tenantTransactionManager")
    public JpaTransactionManager transactionManager(EntityManagerFactory entityManagerFactory){
        JpaTransactionManager transactionManager = new JpaTransactionManager();
        transactionManager.setEntityManagerFactory(entityManagerFactory);
        return transactionManager;
    }

    @Bean(name = "datasourceBasedMultiTenantConnectionProvider")
    @ConditionalOnBean(name = "masterEntityManagerFactory")
    public MultiTenantConnectionProvider multiTenantConnectionProvider(){
        return new DataSourceBasedMultiTenantConnectionProviderImpl();
    }
	 @Bean(name = "currentTenantIdentifierResolver")
    public CurrentTenantIdentifierResolver currentTenantIdentifierResolver(){
        return new CurrentTenantIdentifierResolverImpl();
    }

    @Bean(name = "tenantEntityManagerFactory")
    @ConditionalOnBean(name = "datasourceBasedMultiTenantConnectionProvider")
    public LocalContainerEntityManagerFactoryBean entityManagerFactory(
            @Qualifier("datasourceBasedMultiTenantConnectionProvider")MultiTenantConnectionProvider connectionProvider,
            @Qualifier("currentTenantIdentifierResolver")CurrentTenantIdentifierResolver tenantIdentifierResolver
    ){
        LocalContainerEntityManagerFactoryBean localBean = new LocalContainerEntityManagerFactoryBean();
        localBean.setPackagesToScan(
                new String[]{
                        User.class.getPackage().getName(),
                        UserRepository.class.getPackage().getName(),
                        UserService.class.getPackage().getName()

                }
        );
		localBean.setJpaVendorAdapter(jpaVendorAdapter());
        localBean.setPersistenceUnitName("tenant-database-persistence-unit");
        Map<String,Object> properties = new HashMap<>();
        properties.put(Environment.MULTI_TENANT, MultiTenancyStrategy.SCHEMA);
        properties.put(Environment.MULTI_TENANT_CONNECTION_PROVIDER,connectionProvider);
        properties.put(Environment.MULTI_TENANT_IDENTIFIER_RESOLVER,tenantIdentifierResolver);
        properties.put(Environment.DIALECT,"org.hibernate.dialect.MySQL5Dialect");
        properties.put(Environment.SHOW_SQL,true);
        properties.put(Environment.FORMAT_SQL,true);
        properties.put(Environment.HBM2DDL_AUTO,"update");
        localBean.setJpaPropertyMap(properties);
        return localBean;
    }
}
In the configuration file, most of the content is the same as the configuration of the main data source. The only difference is the settings of the tenant identification resolver and the tenant data source supply source. It will tell Hibernate what to set before executing the database operation command Database connection information, and information such as user name and password.

10. Application Testing
Finally, we use a simple login case to test the SaaS application in this course. For this, we need to provide a Controller to handle user login logic. In this case, the user password is not strictly encrypted, but plain text is used for comparison, and no authorization authentication framework is provided. The knowledge simply verifies whether the basic features of SaaS are available. The login controller code is as follows:

/**
 * @author : Created by Tan Chaohong (alias:ramostear)
 * @create-time 2019/5/27 0027-0:18
 * @modify by :
 * @since:
 */
@Controller
public class LoginController {

    @Autowired
    private UserService userService;

    @GetMapping("/login.html")
    public String login(){
        return "/login";
    }

    @PostMapping("/login")
    public String login(@RequestParam(name = "username") String username, @RequestParam(name = "password")String password, ModelMap model){
        System.out.println("tenant:"+TenantContextHolder.getTenant());
        User user = userService.findByUsername(username);
        if(user != null){
            if(user.getPassword().equals(password)){
                model.put("user",user);
                return "/index";
            }else{
                return "/login";
            }
        }else{
            return "/login";
        }
    }
}
Before starting the project, we need to create a corresponding database and data table for the main data source to store tenant data source information. At the same time, we also need to provide a tenant business module database and data table to store tenant business data. After everything is ready, start the project and type in the browser: http://localhost:8080/login.html


Enter the corresponding tenant name, user name and password in the login window to test whether the homepage can be reached normally. You can add several more tenants and users to test whether the users normally switch to the corresponding tenant.

Summary
Here, I shared the method of using Spring Boot+JPA to quickly implement multi-tenant applications. This method only involves the core technical means to implement the SaaS application platform, not a complete and usable project code, such as user authentication and authorization. Etc. did not appear in this article. Friends who are interested in additional business modules can extend this design by themselves. If you have any questions about the code, please leave a message below.

The source code involved in this tutorial has been uploaded to Github. If you don't need to continue reading the following content, you can directly click this link to get the source code content. https://github.com/ramostear/una-saas-toturial
